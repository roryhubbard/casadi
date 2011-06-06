%{
#include "casadi/matrix/crs_sparsity.hpp"
#include "casadi/matrix/matrix.hpp"
#include <sstream>
#include "casadi/casadi_exception.hpp"

// to allow for typechecking
#include "casadi/matrix/matrix.hpp"
#include "casadi/sx/sx.hpp"

// to typecheck for MX
#include "casadi/mx/mx.hpp"
%}

%include "typemaps.i"

/// Generic typemap structure

%inline %{

#ifdef SWIGPYTHON
#define GUESTOBJECT PyObject * p
#endif // SWIGPYTHON

#ifdef  SWIGOCTAVE
#define GUESTOBJECT const octave_value& p
#endif // SWIGOCTAVE

/** Check if Guest object is of a particular SWIG type */
bool istype(GUESTOBJECT, swig_type_info *type) {
  return SWIG_IsOK(SWIG_ConvertPtr(p, 0, type, 0));
}

template<class T>
class meta {
  public:
    /// Check if Python object is of type T
    static bool isa(GUESTOBJECT) {
      return istype(p,*meta<T>::name);
    };
    /// Convert Python object to pointer of type T
    static bool get_ptr(GUESTOBJECT,T*& m) {
      void *pd = 0 ;
      int res = SWIG_ConvertPtr(p, &pd,*meta<T>::name, 0 );
      if (!SWIG_IsOK(res)) {
        return false;
      }
      m = reinterpret_cast< T*  >(pd);
      return true;
    };
    /// Convert Guest object to type T
    static int as(GUESTOBJECT,T&);
    /// Check if Guest object could ultimately be converted to type T
    static bool couldbe(GUESTOBJECT);
    static swig_type_info** name;
    static char expected_message[];
    
    // Vector specific stuff
    
    #ifdef SWIGPYTHON
    static bool couldbe_sequence(PyObject * p) {
      if(PySequence_Check(p) && !meta< CasADi::Matrix<CasADi::SX> >::isa(p) && !meta< CasADi::MX >::isa(p)) {
        PyObject *it = PyObject_GetIter(p);
        PyObject *pe;
        int i=0;
        while (pe = PyIter_Next(it)) {                                // Iterate over the sequence inside the sequence
          if (!meta< T >::couldbe(pe)) {
            Py_DECREF(pe);Py_DECREF(it);return false;
          }
          Py_DECREF(pe);
        }
        Py_DECREF(it);
        return true;
      } else {
        return false;
      }
    }
    #endif // SWIGPYTHON
    
    // Assumes that p is a PYTHON sequence
    #ifdef SWIGPYTHON
    static int as_vector(PyObject * p, std::vector<T> &m) {
      PyObject *it = PyObject_GetIter(p);
      PyObject *pe;
      m.resize(PySequence_Size(p));
      int i=0;
      while (pe = PyIter_Next(it)) {                                // Iterate over the sequence inside the sequence
        bool result=meta< T >::as(pe,m[i++]);
        if (!result) {
          Py_DECREF(pe);Py_DECREF(it);
          return false;
        }
        Py_DECREF(pe);
      }
      Py_DECREF(it);
      return true;
    }
    #endif // SWIGPYTHON
};

%}


%define %my_generic_const_typemap(Type,Precedence) 
%typemap(in) const Type & (Type m) {
  if (meta< Type >::isa($input)) { // Type object get passed on as-is, and fast.
    int result = meta< Type >::get_ptr($input,$1);
    if (!result)
      SWIG_exception_fail(SWIG_TypeError,"Type cast failed");
  } else {
    bool result=meta< Type >::as($input,m);
    if (!result)
      SWIG_exception_fail(SWIG_TypeError,meta< Type >::expected_message);
    $1 = &m;
  }
}

%typemap(typecheck,precedence=Precedence) const Type & { $1 = meta< Type >::couldbe($input); }
%typemap(freearg) const Type  & {}

%enddef



%inline %{
#define NATIVERETURN(Type, m) if (meta<Type>::isa(p)) { Type *mp; int result = meta<Type>::get_ptr(p,mp); if (!result) return false; m=*mp; return true;}
%}

%inline %{
template<> swig_type_info** meta< CasADi::Matrix<double> >::name = &SWIGTYPE_p_CasADi__MatrixT_double_t;
%}

#ifdef SWIGPYTHON
%inline%{
/** Check PyObjects by class name */
bool PyObjectHasClassName(PyObject* p, const char * name) {
  PyObject * classo = PyObject_GetAttrString( p, "__class__");
  PyObject * classname = PyObject_GetAttrString( classo, "__name__");
  
  bool ret = strcmp(PyString_AsString(classname),name)==0;
  Py_DECREF(classo);Py_DECREF(classname);
	return ret;
}

bool PyIsSequence(PyObject* p) {
  return PySequence_Check(p) && !meta< CasADi::Matrix<CasADi::SX> >::isa(p) && !meta< CasADi::MX >::isa(p);
}

%}
#endif // SWIGPYTHON


#ifdef SWIGPYTHON
%define %python_matrix_convertors
%pythoncode %{
        
    def toList(self):
        return list(self.data())
        
    def toMatrix(self):
        import numpy as n
        return n.matrix(self.toArray())
%}
%enddef 
%define %python_matrix_helpers
%pythoncode %{
    @property
    def shape(self):
        return (self.size1(),self.size2())
        
    def reshape(self,arg):
        return reshape(self,arg)
        
    @property
    def T(self):
        return trans(self)
        
%}
%enddef 
#endif // SWIGPYTHON

/// CasADi::Matrix<double>
#ifdef SWIGPYTHON
%inline %{
template<> char meta< CasADi::Matrix<double> >::expected_message[] = "Expecting numpy.array2D, numpy.matrix, csr_matrix, DMatrix";

template <>
int meta< CasADi::Matrix<double> >::as(PyObject * p,CasADi::Matrix<double> &m) {
  NATIVERETURN(CasADi::Matrix<double>,m)
  if (is_array(p)) { // Numpy arrays will be cast to dense Matrix<double>
    if (array_numdims(p)>2 || array_numdims(p)<1) {
      SWIG_Error(SWIG_TypeError, "asMatrixDouble: Number of dimensions must be 1 or 2.");
      std::stringstream s;
      s << "SWIG::typemapDMatrixHelper:";
      s << "Number of dimensions must be 1 or 2.";
      s << "Got " << array_numdims(p) << " instead.";
      const std::string tmp(s.str());
      const char* cstr = tmp.c_str();
      SWIG_Error(SWIG_TypeError,  cstr);
    }
    int nrows = array_size(p,0); // 1D array is cast into column vector
    int ncols  = 1;
    if (array_numdims(p)==2)
      ncols=array_size(p,1); 
    int size=nrows*ncols; // number of elements in the dense matrix
    if (!array_is_native(p)) 
      SWIG_Error(SWIG_TypeError, "asMatrixDouble: array byte order should be native.");
    // Make sure we have a contigous array with double datatype
    int array_is_new_object;
    PyArrayObject* array = obj_to_array_contiguous_allow_conversion(p,NPY_DOUBLE,&array_is_new_object);

    double* d=(double*) array->data;
    std::vector<double> v(d,d+size);
    
    m = CasADi::Matrix<double>(v, nrows, ncols);
                  
    // Free memory
    if (array_is_new_object)
      Py_DECREF(array); 
  } else if(PyObjectHasClassName(p,"csr_matrix")) { // scipy's csr_matrix will be cast to sparse Matrix<double>
    PyObject * narray=PyObject_GetAttrString( p, "data"); // need's to be decref'ed
    if (!(is_array(narray) && array_numdims(narray)==1))
      SWIG_Error(SWIG_TypeError, "asMatrixDouble: data should be numpy array");
    int array_is_new_object;
    PyArrayObject* array = obj_to_array_contiguous_allow_conversion(narray,NPY_DOUBLE,&array_is_new_object);
    int size=array_size(array,0); // number on non-zeros
    double* d=(double*) array->data;
    std::vector<double> v(d,d+size);

    // Get the dimensions of the csr_matrix
    PyObject * shape = PyObject_GetAttrString( p, "shape"); // need's to be decref'ed
    int nrows=PyInt_AsLong(PyTuple_GetItem(shape,0));
    int ncols=PyInt_AsLong(PyTuple_GetItem(shape,1));
		
    // Construct the 'col' vector needed for initialising the correct sparsity
    PyObject * col = PyObject_GetAttrString(p,"indices"); // need's to be decref'ed
    if (!(is_array(col) && array_numdims(col)==1 && array_type(col)==NPY_INT))
      SWIG_Error(SWIG_TypeError, "asMatrixDouble: data.indices should be numpy array");
    int* cold=(int*) array_data(col);
    std::vector<int> colv(cold,cold+size);
    
    // Construct the 'rowind' vector needed for initialising the correct sparsity
    PyObject * rowind = PyObject_GetAttrString(p,"indptr"); // need's to be decref'ed
    if (!(is_array(rowind) && array_numdims(rowind)==1 && array_type(rowind)==NPY_INT))
      SWIG_Error(SWIG_TypeError, "asMatrixDouble: data.indptr should be numpy array");
    int* rowindd=(int*) array_data(rowind);
    std::vector<int> rowindv(rowindd,rowindd+(nrows+1));
    
    m = CasADi::Matrix<double>(nrows,ncols,colv,rowindv, v);
    
    Py_DECREF(narray);Py_DECREF(shape);Py_DECREF(col);Py_DECREF(rowind);
    
    if (array_is_new_object)
      Py_DECREF(array);
  } else {
    SWIG_Error(SWIG_TypeError, "asDMatrix: unrecognised type. Should have been caught by typemap(typecheck)");
    return false;
  }
  return true;
}

// Disallow 1D numpy arrays. Allowing them may introduce conflicts with other typemaps or overloaded methods
template <>
bool meta< CasADi::Matrix<double> >::couldbe(PyObject * p) {
  return ((is_array(p) && array_numdims(p)==2) && array_type(p)!=NPY_OBJECT|| PyObjectHasClassName(p,"csr_matrix") || PyObjectHasClassName(p,"DMatrix")) ;
}

%}
#endif //SWIGPYTHON


/// CasADi::Matrix<double>
#ifdef SWIGOCTAVE
%inline %{
template<> char meta< CasADi::Matrix<double> >::expected_message[] = "Expecting numpy.array2D, numpy.matrix, csr_matrix, DMatrix";

template <>
int meta< CasADi::Matrix<double> >::as(const octave_value& p,CasADi::Matrix<double> &m) {
  if(p.is_real_matrix()){
    Matrix mat = p.matrix_value();
    m = CasADi::DMatrix(mat.rows(),mat.cols(),0);
    for(int i=0; i<mat.rows(); ++i){
      for(int j=0; j<mat.cols(); ++j){
        m(i,j) = mat(i,j);
      }
    }
  }
    
  return true;
}

// Disallow 1D numpy arrays. Allowing them may introduce conflicts with other typemaps or overloaded methods
template <>
bool meta< CasADi::Matrix<double> >::couldbe(const octave_value& p) {return p.is_real_matrix();}

%}
#endif //SWIGOCTAVE

#ifdef SWIGPYTHON
namespace CasADi{
%extend Matrix<double> {
/// Create a 2D contiguous NP_DOUBLE numpy.ndarray

#ifdef WITH_NUMPY
PyObject* arrayView() {
  if ($self->size()!=$self->numel()) 
    throw  CasADi::CasadiException("Matrix<double>::arrayview() can only construct arrayviews for dense DMatrices.");
  npy_intp dims[2];
  dims[0] = $self->size1();
  dims[1] = $self->size2();
  std::vector<double> &v = $self->data();
  return PyArray_SimpleNewFromData(2, dims, NPY_DOUBLE, &v[0]);
}
#endif WITH_NUMPY


%python_matrix_convertors
%python_matrix_helpers

%pythoncode %{
  __array_priority__ = 999
%}
    
    
%pythoncode %{
  def toArray(self,shared=False):
    import numpy as n
    if shared:
      if self.size()!=self.numel():
        raise Expection("toArray(shared=True) only possible for dense arrays.")
      return self.arrayView()
    else:
      r = n.zeros((self.size1(),self.size2()))
      self.get(r)
    return r
%}

%pythoncode %{
  def __array_wrap__(self,out_arr,context=None):
    name = context[0].__name__
    conversion = {"multiply": "mul", "divide": "div", "subtract":"sub","power":"pow"}
    if name in conversion:
      name = conversion[name]
    if len(context[1])==2 and context[1][1] is self:
      name = 'r' + name
    if not(hasattr(self,name)):
      name = '__' + name + '__'
    fun=getattr(self, name)
    return fun(*context[1][0:-1])
%}

// The following code has some trickery to fool numpy ufunc.
// Normally, because of the presence of __array__, an ufunctor like nump.sqrt
// will unleash its activity on the output of __array__
// However, we wish DMatrix to remain a DMatrix
// So when we receive a call from a functor, we return a dummy empty array
// and return the real result during the postprocessing (__array_wrap__) of the functor.
%pythoncode %{
  def __array__(self,*args,**kwargs):
    import numpy as n
    if len(args) > 1 and isinstance(args[1],tuple) and isinstance(args[1][0],n.ufunc):
      return n.array([])
    else:
      if "dtype" in kwargs and not(isinstance(kwargs["dtype"],n.double)):
        return n.array(self.toArray(),dtype=kwargs["dtype"])
      else:
        return self.toArray()

%}

%pythoncode %{
  def toCsr_matrix(self):
    import numpy as n
    from scipy.sparse import csr_matrix
    return csr_matrix( (list(self.data()),self.sparsity().col(),self.sparsity().rowind()), shape = (self.size1(),self.size2()), dtype=n.double )
%}


}; // extend Matrix<double>
} // namespace CasADi
#endif // SWIGPYTHON


/** If the array is of type double, contiguous and in native byte order, this function is efficient.
* Other types of numpy array will trigger conversion, requiring temporary allocation of memory.
*/


namespace CasADi{
  
#ifdef SWIGPYTHON


%typemap(in) (const CasADi::Slice& i, const CasADi::Slice &j) (CasADi::Slice temp[2]) {
  for(int i=0; i<2; ++i){
    PyObject *q = PyTuple_GetItem($input,i);
    if(PyInt_Check(q)){
      temp[i].start = PyInt_AsLong(q);
      temp[i].stop = temp[i].start+1;
    } else{
      PySliceObject *r = (PySliceObject*)(q);
      if(r->start!=Py_None) temp[i].start = PyInt_AsLong(r->start);
      if(r->stop !=Py_None) temp[i].stop  = PyInt_AsLong(r->stop);
      if(r->step !=Py_None) temp[i].step  = PyInt_AsLong(r->step);
    }
  }
    
  $1 = &temp[0];
  $2 = &temp[1];
}

%typemap(typecheck,precedence=PRECEDENCE_PAIR_SLICE_SLICE) (const CasADi::Slice& i, const CasADi::Slice &j) {
  $1 = PyTuple_Check($input) 
  && (PySlice_Check(PyTuple_GetItem($input,0)) || PyInt_Check(PyTuple_GetItem($input,0))) 
  && (PySlice_Check(PyTuple_GetItem($input,1)) || PyInt_Check(PyTuple_GetItem($input,1)));
}

%typemap(in) const Slice &  (CasADi::Slice temp){
  PySliceObject *r = (PySliceObject*)($input);
  if(r->start!=Py_None) temp.start = PyInt_AsLong(r->start);
  if(r->stop !=Py_None) temp.stop  = PyInt_AsLong(r->stop);
  if(r->step !=Py_None) temp.step  = PyInt_AsLong(r->step);
  $1 = &temp;
}

%typemap(typecheck,precedence=PRECEDENCE_SLICE) const Slice & {
  $1 = PySlice_Check($input);
}
#endif // SWIGPYTHON

%my_generic_const_typemap(CasADi::Matrix<double>,PRECEDENCE_DMatrix);

#ifdef SWIGPYTHON
#ifdef WITH_NUMPY
/**
Accepts: 2D numpy.ndarray, numpy.matrix (contiguous, native byte order, datatype double)   - DENSE
         1D numpy.ndarray, numpy.matrix (contiguous, native byte order, datatype double)   - SPARSE
         2D scipy.csr_matrix
*/

%typemap(in,numinputs=1) (double * val,int len,int stride1, int stride2,Sparsity sp)  {
	PyObject* p = $input;
	$3 = 0;
	$4 = 0;
	if (is_array(p)) {
			if (!(array_is_native(p) && array_type(p)==NPY_DOUBLE))
			  SWIG_exception_fail(SWIG_TypeError, "Array should be native & of datatype double");
			  
	    if (!(array_is_contiguous(p))) {
	      if (PyArray_CHKFLAGS(p,NPY_ALIGNED)) {
	        $3 = PyArray_STRIDE(p,0)/sizeof(double);
	        $4 = PyArray_STRIDE(p,1)/sizeof(double);
	      } else {
			   SWIG_exception_fail(SWIG_TypeError, "Array should be contiguous or aligned");
	      }
	    }
	    
			if (array_numdims(p)==2) {
				if (!(array_size(p,0)==arg1->size1() && array_size(p,1)==arg1->size2()) ) {
				  std::stringstream s;
				  s << "SWIG::typemap(in) (double *val,int len,Sparsity sp) " << std::endl;
				  s << "Array is not of correct shape.";
				  s << "Expecting shape (" << arg1->size1() << "," << arg1->size2() << ")" << ", but got shape (" << array_size(p,0) << "," << array_size(p,1) <<") instead.";
          const std::string tmp(s.str());
          const char* cstr = tmp.c_str();
			    SWIG_exception_fail(SWIG_TypeError,  cstr);
			  }
			  $5 = CasADi::DENSE;
			  $2 = array_size(p,0)*array_size(p,1);
			  $1 = (double*) array_data(p);
			} else if (array_numdims(p)==1) {
				if (!(array_size(p,0)==arg1->size()) ) {
				  std::stringstream s;
				  s << "SWIG::typemap(in) (double *val,int len,Sparsity sp) " << std::endl;
				  s << "Array is not of correct size. Should match number of non-zero elements.";
				  s << "Expecting " << array_size(p,0) << " non-zeros, but got " << arg1->size() <<" instead.";
          const std::string tmp(s.str());
          const char* cstr = tmp.c_str();
			    SWIG_exception_fail(SWIG_TypeError,  cstr);
			  }
			  $5 = CasADi::SPARSE;
			  $2 = array_size(p,0);
			  $1 = (double*) array_data(p);
			} else {
			  SWIG_exception_fail(SWIG_TypeError, "Expecting 1D or 2D numpy.ndarray");
			}
	} else if (PyObjectHasClassName(p,"csr_matrix")) {
			$5 = CasADi::SPARSE;
			PyObject * narray=PyObject_GetAttrString( p, "data"); // narray needs to be decref'ed
			if (!(array_is_contiguous(narray) && array_is_native(narray) && array_type(narray)==NPY_DOUBLE))
			  SWIG_exception_fail(SWIG_TypeError, "csr_matrix should be contiguous, native & of datatype double");
			$2 = array_size(narray,0);
			if (!(array_size(narray,0)==arg1->size() ) ) {
					std::stringstream s;
				  s << "SWIG::typemap(in) (double *val,int len,Sparsity sp) " << std::endl;
				  s << "csr_matrix does not have correct number of non-zero elements.";
				  s << "Expecting " << arg1->size() << " non-zeros, but got " << array_size(narray,0) << " instead.";
          const std::string tmp(s.str());
          const char* cstr = tmp.c_str();
		      Py_DECREF(narray);
			    SWIG_exception_fail(SWIG_TypeError,  cstr);
			}
			$1 = (double*) array_data(narray);
			Py_DECREF(narray);
	} else {
			SWIG_exception_fail(SWIG_TypeError, "Unrecognised object");
	}
	
}

/**
Accepts: 2D numpy.ndarray, numpy.matrix (any setting of contiguous, native byte order, datatype)  - DENSE
         1D numpy.ndarray, numpy.matrix (any setting of contiguous, native byte order, datatype double) - SPARSE
         2D scipy.csr_matrix (any setting of contiguous, native byte order, datatype double) 
*/
%typemap(in,numinputs=1) (const double *val,int len,Sparsity sp) (PyArrayObject* array, int array_is_new_object=0)  {
	PyObject* p = $input;
	if (is_array(p)) {
			array = obj_to_array_contiguous_allow_conversion(p,NPY_DOUBLE,&array_is_new_object);
			if (array_numdims(array)==2) {
				if (!(array_size(array,0)==arg1->size1() && array_size(array,1)==arg1->size2()) ) {
				  std::stringstream s;
				  s << "SWIG::typemap(in) (const double *val,int len,Sparsity sp) " << std::endl;
				  s << "Array is not of correct shape.";
				  s << "Expecting shape (" << arg1->size1() << "," << arg1->size2() << ")" << ", but got shape (" << array_size(array,0) << "," << array_size(array,1) <<") instead.";
          const std::string tmp(s.str());
          const char* cstr = tmp.c_str();
			    SWIG_exception_fail(SWIG_TypeError,  cstr);
			  }
			  $3 = CasADi::DENSE;
			  $2 = array_size(array,0)*array_size(array,1);
			  $1 = (double*) array_data(array);
			} else if (array_numdims(array)==1) {
				if (!(array_size(array,0)==arg1->size()) ) {
				  std::stringstream s;
				  s << "SWIG::typemap(in) (const double *val,int len,Sparsity sp) " << std::endl;
				  s << "Array is not of correct size. Should match number of non-zero elements.";
				  s << "Expecting " << arg1->size() << " non-zeros, but got " << array_size(array,0) << " instead.";
          const std::string tmp(s.str());
          const char* cstr = tmp.c_str();
			    SWIG_exception_fail(SWIG_TypeError,  cstr);
			  }
			  $3 = CasADi::SPARSE;
			  $2 = array_size(array,0);
			  $1 = (double*) array_data(array);
			} else {
			  SWIG_exception_fail(SWIG_TypeError, "Expecting 1D or 2D numpy.ndarray");
			}
	} else if (PyObjectHasClassName(p,"csr_matrix")) {
			$3 = CasADi::SPARSE;
			PyObject * narray=PyObject_GetAttrString( p, "data"); // narray needs to be decref'ed
			$2 = array_size(narray,0);
			if (!(array_size(narray,0)==arg1->size() ) ) {
					std::stringstream s;
				  s << "SWIG::typemap(in) (const double *val,int len,Sparsity sp) " << std::endl;
				  s << "csr_matrix does not have correct number of non-zero elements.";
				  s << "Expecting " << arg1->size() << " non-zeros, but got " << array_size(narray,0) << " instead.";
          const std::string tmp(s.str());
          const char* cstr = tmp.c_str();
          Py_DECREF(narray);
			    SWIG_exception_fail(SWIG_TypeError,  cstr);
			}
			array = obj_to_array_contiguous_allow_conversion(narray,NPY_DOUBLE,&array_is_new_object);
			$1 = (double*) array_data(array);
			Py_DECREF(narray);
	} else {
			SWIG_exception_fail(SWIG_TypeError, "Unrecognised object");
	}
	
}

%typemap(freearg) (const double *val,int len,Sparsity sp) {
    if (array_is_new_object$argnum && array$argnum) { Py_DECREF(array$argnum); }
}


%typemap(typecheck,precedence=SWIG_TYPECHECK_INTEGER) (double * val,int len,int stride1, int stride2,Sparsity sp) {
  PyObject* p = $input;
  if ((is_array(p) && array_numdims(p) < 3)  && array_type(p)!=NPY_OBJECT|| PyObjectHasClassName(p,"csr_matrix")) {
    $1=1;
  } else {
    $1=0;
  }
}

%typemap(typecheck,precedence=SWIG_TYPECHECK_INTEGER) (const double * val,int len,Sparsity sp) {
  PyObject* p = $input;
  if ((is_array(p) && array_numdims(p) < 3)  && array_type(p)!=NPY_OBJECT|| PyObjectHasClassName(p,"csr_matrix")) {
    $1=1;
  } else {
    $1=0;
  }
}
#endif // WITH_NUMPY
#endif // SWIGPYTHON

// #ifdef SWIGOCTAVE
// %typemap(in) const std::vector<int> &  (std::vector<int> temp){
//   Matrix mat = $input.matrix_value();
//   temp.resize(mat.rows()*mat.cols());
//   for(int i=0; i<mat.rows(); ++i){
//     for(int j=0; j<mat.cols(); ++j){
//       temp[i+j*mat.rows()] = int(mat(i,j));
//     }
//   }
//   $1 = &temp;
// }
// 
// %typemap(typecheck,precedence=PRECEDENCE_SLICE) const std::vector<int> & {
//   $1 = $input.is_real_matrix();
// }
// #endif // SWIGOCTAVE


} // namespace CasADi
