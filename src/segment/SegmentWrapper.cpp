#ifdef WITH_PYTHON_PORT
#include <Python.h>
#include "HistologicalEntities.h"

static PyObject *segmentNucleiStg1Py(PyObject *self, PyObject *args) {
    // Parse arguments
    // cv::Mat &img;
    unsigned char blue;
    unsigned char green;
    unsigned char red;
    double T1;
    double T2;

    std::vector<cv::Mat> *bgr;
    cv::Mat *rbc;



    if (!PyArg_ParseTuple(args, "bbbdd", &blue, &green, &red, &T1, &T2)) {
        return NULL;
    }

    ::nscale::HistologicalEntities::helloWorld(blue, green, red, T1, T2);

    return PyLong_FromLong(0);
}

static PyMethodDef SegmentMethods[] = {
    {"segmentNucleiStg1", segmentNucleiStg1Py, METH_VARARGS,
     "segmentNucleiStg1 C function"},
    {NULL, NULL, 0, NULL}};

static struct PyModuleDef segmentmodule = {PyModuleDef_HEAD_INIT, "ligsegment",
                                         "nscale segment C module", -1, SegmentMethods};

PyMODINIT_FUNC PyInit_libsegment(void) { return PyModule_Create(&segmentmodule); }

#endif