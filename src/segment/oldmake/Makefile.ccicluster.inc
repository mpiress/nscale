CXX=g++
CXXFLAGS=-fPIC -pg -O3 -fopenmp #-g -msse4.2 
#CXX=icpc
#CXXFLAGS=-g -fast -openmp -msse4.2

RM=/bin/rm -rf

CUDA_CV_INCLUDE =-I/opt/local/include -I/opt/local/include/opencv2/gpu
CXXFLAGS	+= -I/opt/local/include -I/opt/local/include/opencv -I. -I../features
CXXFLAGS	+= ${CUDA_CV_INCLUDE} 
LDFLAGS		+= -L/opt/local/lib -lopencv_core -lopencv_imgproc -lopencv_highgui -lopencv_ml -lopencv_video -lopencv_features2d -lopencv_calib3d -lopencv_objdetect -lopencv_contrib -lopencv_legacy -lopencv_flann 
LDFLAGS		+= -lopencv_gpu

