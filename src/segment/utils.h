/*
 * utils.h
 *
 *  Created on: Jul 15, 2011
 *      Author: tcpan
 */

#ifndef UTILS_H_
#define UTILS_H_

#include "cv.h"
#include <fstream>
#include <iostream>
#include <sys/time.h>

namespace cciutils {

const int DEVICE_CPU = 0;
const int DEVICE_MCORE = 1;
const int DEVICE_GPU = 2;

//convert double to unsigned char
inline unsigned char double2uchar(double d){
	double truncate = std::min( std::max(d,(double)0.0), (double)255.0);
	double pt;
	double c = modf(truncate, &pt)>=.5?ceil(truncate):floor(truncate);
	return (unsigned char)c;
}

inline uint64_t ClockGetTime()
{
	struct timeval ts;
	gettimeofday(&ts, NULL);
 //   timespec ts;
//    clock_gettime(CLOCK_REALTIME, &ts);
	return (ts.tv_sec*1000000 + (ts.tv_usec))/1000LL;
//    return (uint64_t)ts.tv_sec * 1000000LL + (uint64_t)ts.tv_nsec / 1000LL;
}

template <typename T>
inline T min()
{
	if (std::numeric_limits<T>::is_integer) {
		return std::numeric_limits<T>::min();
	} else {
		return -std::numeric_limits<T>::max();
	}
}

template <typename T>
inline bool sameSign(T a, T b) {
	return ((a^b) >= 0);
}

class SimpleCSVLogger {
public :

	SimpleCSVLogger(const char* name) {
		char headername[1024];
		char valuename[1024];
		strcpy(headername, name);
		strcat(headername, "-header.csv");
		strcpy(valuename, name);
		strcat(valuename, "-value.csv");
		header.open(headername, std::ios_base::out | std::ios_base::app);
		value.open(valuename, std::ios_base::out | std::ios_base::app);
		start = 0;
		curr = 0;
		last = 0;
		_consoleOn = true;
		_on = true;
	};
	~SimpleCSVLogger() {
		header.flush();
		header.close();
		value.flush();
		value.close();
	};
	
	void endSession() {
		if (_on) {
			header << std::endl;
			value << std::endl;
			header.flush();
			value.flush();
		};
	}

	template <typename T>
	void log(const char* eventName, T eventVal) {
		if (_on) {
			header << eventName << ", ";
			value << eventVal << ", ";
		}
		if (_consoleOn) {
			std::cout << "[LOGGER] " << eventName << ": " << eventVal << std::endl;
		}
	};
	void logTimeElapsedSinceLastLog(const char* eventName) {
		curr = cciutils::ClockGetTime();
		if (last == 0) last = curr;
		log(eventName, curr - last);
		last = curr;
	}
	void logTimeElapsedSinceStart(const char* eventName) {
		curr = cciutils::ClockGetTime();
		if (start == 0) start = curr;
		log(eventName, curr - start);
	}
	void logStart(const char* eventName) {
		start = cciutils::ClockGetTime();
		last = start;
		log(eventName, (uint64_t)0);
	}
	void off() {
		_on = false;
	}
	void on() {
		_on = true;
	}
	void consoleOff() {
		_consoleOn = false;
	}
	void consoleOn() {
		_consoleOn = true;
	}
protected :
	std::ofstream header;
	std::ofstream value;
	uint64_t start;
	uint64_t last;
	uint64_t curr;
	bool _on;
	bool _consoleOn;
};

namespace cv {

using ::cv::Exception;
using ::cv::error;

inline void imwriteRaw(const char *prefix, const ::cv::Mat& img) {
	// write the raw image
	char * filename = new char[128];
	int cols = img.cols;
	int rows = img.rows;
	sprintf(filename, "%s_%d_x_%d.raw", prefix, cols, rows);
	FILE* fid = fopen(filename, "wb");
	const uchar* imgPtr;
	int elSize = img.elemSize();
	for (int j = 0; j < rows; ++j) {
		imgPtr = img.ptr(j);

		fwrite(imgPtr, elSize, cols, fid);
	}
	fclose(fid);

}


}


}




#endif /* UTILS_H_ */
