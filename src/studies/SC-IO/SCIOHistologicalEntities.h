/*
 * HistologicalEntities.h
 *
 *  Created on: Jul 1, 2011
 *      Author: tcpan
 */

#ifndef SCIO_HistologicalEntities_H_
#define SCIO_HistologicalEntities_H_

#include "SCIOUtilsCVImageIO.h"
#include "SCIOUtilsLogger.h"
#include "opencv2/opencv.hpp"
#include "opencv2/gpu/gpu.hpp"
#include <string.h>

namespace nscale {

class SCIOHistologicalEntities {

public:


	static const int BACKGROUND = 1;
	static const int BACKGROUND_LIKELY = 2;
	static const int NO_CANDIDATES_LEFT = 3;
	static const int INVALID_IMAGE = -1;
	static const int SUCCESS = 0;
	static const int CONTINUE = 4;
	static const int RUNTIME_FAILED = -2;


	SCIOHistologicalEntities(std::string _filename) : filename(_filename) {};
	virtual ~SCIOHistologicalEntities() {};

	cv::Mat getRBC(const cv::Mat& img,
			::cciutils::SCIOLogger *logger = NULL, ::cciutils::cv::IntermediateResultHandler *iresHandler = NULL);
	cv::Mat getRBC(const std::vector<cv::Mat>& bgr,
			::cciutils::SCIOLogger *logger = NULL, ::cciutils::cv::IntermediateResultHandler *iresHandler = NULL);
	cv::Mat getBackground(const cv::Mat& img,
			::cciutils::SCIOLogger *logger = NULL, ::cciutils::cv::IntermediateResultHandler *iresHandler = NULL);
	cv::Mat getBackground(const std::vector<cv::Mat>& bgr,
			::cciutils::SCIOLogger *logger = NULL, ::cciutils::cv::IntermediateResultHandler *iresHandler = NULL);

	int segmentNuclei(const cv::Mat& img, cv::Mat& mask,
			int &compcount, int *&bbox,
			::cciutils::SCIOLogger *logger = NULL, ::cciutils::cv::IntermediateResultHandler *iresHandler = NULL);
	int segmentNuclei(const std::string& input, const std::string& output,
			int &compcount, int *&bbox,
			::cciutils::SCIOLogger *logger = NULL, ::cciutils::cv::IntermediateResultHandler *iresHandler = NULL);

	// the following are specific to the task based implementation for HPDC paper.  The pipeline is refactoring into this form so we're maintaining one set of code.
	int plFindNucleusCandidates(const cv::Mat& img, cv::Mat& seg_norbc,
			::cciutils::SCIOLogger *logger = NULL, ::cciutils::cv::IntermediateResultHandler *iresHandler = NULL);  // S1
	int plSeparateNuclei(const cv::Mat& img, const cv::Mat& seg_open, cv::Mat& seg_nonoverlap,
			::cciutils::SCIOLogger *logger = NULL, ::cciutils::cv::IntermediateResultHandler *iresHandler = NULL); // A4

private:
	std::string filename;

};


namespace gpu {

class SCIOHistologicalEntities {

public:
	SCIOHistologicalEntities(std::string _filename) : filename(_filename) {};
	virtual ~SCIOHistologicalEntities() {};



	cv::gpu::GpuMat getRBC(const std::vector<cv::gpu::GpuMat>& bgr, cv::gpu::Stream& stream,
			::cciutils::SCIOLogger *logger = NULL, ::cciutils::cv::IntermediateResultHandler *iresHandler = NULL);
	cv::gpu::GpuMat getBackground(const std::vector<cv::gpu::GpuMat>& bgr, cv::gpu::Stream& stream,
			::cciutils::SCIOLogger *logger = NULL, ::cciutils::cv::IntermediateResultHandler *iresHandler = NULL);

	int segmentNuclei(const cv::gpu::GpuMat& img, cv::gpu::GpuMat& mask,
			int &compcount, int *&g_bbox, cv::gpu::Stream *str = NULL,
			::cciutils::SCIOLogger *logger = NULL, ::cciutils::cv::IntermediateResultHandler *iresHandler = NULL);
	int segmentNuclei(const cv::Mat& img, cv::Mat& mask,
			int &compcount, int *&bbox, cv::gpu::Stream *str = NULL,
			::cciutils::SCIOLogger *logger = NULL, ::cciutils::cv::IntermediateResultHandler *iresHandler = NULL);
	int segmentNuclei(const std::string& input, const std::string& output,
			int &compcount, int *&bbox, cv::gpu::Stream *str = NULL,
			::cciutils::SCIOLogger *logger = NULL, ::cciutils::cv::IntermediateResultHandler *iresHandler = NULL);

	// the following are specific to the task based implementation for HPDC paper.  The pipeline is refactoring into this form so we're maintaining one set of code.
	int plFindNucleusCandidates(const cv::gpu::GpuMat& g_img, cv::gpu::GpuMat& g_seg_norbc, cv::gpu::Stream& stream,
			::cciutils::SCIOLogger *logger = NULL, ::cciutils::cv::IntermediateResultHandler *iresHandler = NULL);  // S1
	int plSeparateNuclei(const cv::gpu::GpuMat& g_img, cv::gpu::GpuMat& g_seg_open, cv::gpu::GpuMat& g_seg_nonoverlap, cv::gpu::Stream& stream,
			::cciutils::SCIOLogger *logger = NULL, ::cciutils::cv::IntermediateResultHandler *iresHandler = NULL); // A4
private:
	std::string filename;


};

}

}
#endif /* HistologicalEntities_H_ */
