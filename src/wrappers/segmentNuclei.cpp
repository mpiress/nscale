#define PY_ARRAY_UNIQUE_SYMBOL pbcvt_ARRAY_API

#include <boost/python.hpp>
#include <iostream>
#include "pyboostcvconverter.hpp"
#include "segment/HistologicalEntities.h"

namespace pbcvt {

using namespace boost::python;

//PyObject -> Vector
std::vector<cv::Mat> PyObjectToVector(PyObject *incoming) {
	std::vector<cv::Mat> data;
	
	for(Py_ssize_t i=0; i<PyList_Size(incoming); i++) {
		PyObject *value = PyList_GetItem(incoming, i);
		cv::Mat vet = pbcvt::fromNDArrayToMat(value);
		data.push_back(vet);
	}
	
	return data;
}

//Vector -> PyObject
PyObject* VectorToPyObject(vector<cv::Mat> bgr) {
	PyObject* seq = PyList_New(bgr.size());
     
     int i = 0;
     for(std::vector<cv::Mat>::iterator it = bgr.begin() ; it != bgr.end(); ++it){
        PyObject* item = pbcvt::fromMatToNDArray(*it);
        PyList_SET_ITEM(seq, i, item);
        i++;
    }

    return seq;
}


static PyObject *segmentNucleiStg1Py(PyObject *pyimg, PyObject *args) {
    PyObject* result = PyList_New(2);
    unsigned char blue;
    unsigned char green;
    unsigned char red;
    double T1;
    double T2;

    std::vector<cv::Mat> bgr;
    cv::Mat rbc;

    //cv::Mat img = pbcvt::fromNDArrayToMat(pyimg);

    if (!PyArg_ParseTuple(args, "bbbdd", &blue, &green, &red, &T1, &T2)) {
        return NULL;
    }

    ::nscale::HistologicalEntities::helloWorld(blue, green, red, T1, T2);
    
    //PyObject *py_rbc = pbcvt::fromMatToNDArray(rbc);
    //PyObject *py_bgr = VectorToPyObject(bgr);
    //PyList_SET_ITEM(result, 0, py_rbc);
    //PyList_SET_ITEM(result, 1, py_bgr); 

    return PyLong_FromLong(0);
}

#if (PY_VERSION_HEX >= 0x03000000)

static void *init_ar() {
#else
static void init_ar() {
#endif
    Py_Initialize();

    import_array();
    return NUMPY_IMPORT_ARRAY_RETVAL;
}

BOOST_PYTHON_MODULE(pbcvt) {
    // using namespace XM;
    init_ar();

    // initialize converters
    to_python_converter<cv::Mat, pbcvt::matToNDArrayBoostConverter>();
    matFromNDArrayBoostConverter();

    // expose module-level functions
    def("segmentNucleiStg1Py", segmentNucleiStg1Py);
}

}  // end namespace pbcvt
