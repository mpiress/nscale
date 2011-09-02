/*
 * ScanlineOperations.cpp
 *
 *  Created on: Aug 2, 2011
 *      Author: tcpan
 */

#include "PixelOperations.h"
#include <limits>

#include "precomp.hpp"
#include "cuda/pixel-ops.cuh"


namespace nscale {

using namespace cv;

namespace gpu {

using namespace cv::gpu;

template <typename T>
GpuMat PixelOperations::invert(const GpuMat& img, Stream& stream) {
	// write the raw image

    const Size size = img.size();
    const int depth = img.depth();
    const int cn = img.channels();

    GpuMat result(size, CV_MAKE_TYPE(depth, cn));

	if (std::numeric_limits<T>::is_integer) {

		if (std::numeric_limits<T>::is_signed) {
			invertIntCaller<T>(size.height, size.width, cn, img, result, StreamAccessor::getStream(stream));
		} else {
			// unsigned int
			invertUIntCaller<T>(size.height, size.width, cn, img, result, StreamAccessor::getStream(stream));
		}

	} else {
		// floating point type
		invertFloatCaller<T>(size.height, size.width, cn, img, result, StreamAccessor::getStream(stream));
	}

    return result;
}

template GpuMat PixelOperations::invert<unsigned char>(const GpuMat&, Stream&);


template <typename T>
GpuMat PixelOperations::threshold(const GpuMat& img, T lower, T upper, Stream& stream) {
	// write the raw image
	CV_Assert(img.channels() == 1);

    const Size size = img.size();
    const int depth = img.depth();

    GpuMat result(size, CV_8UC1);

    thresholdCaller<T>(size.height, size.width, img, result, lower, upper, StreamAccessor::getStream(stream));

    return result;
}

template GpuMat PixelOperations::threshold<unsigned char>(const GpuMat&, unsigned char, unsigned char, Stream&);
template GpuMat PixelOperations::threshold<float>(const GpuMat&, float, float, Stream&);

}

}

