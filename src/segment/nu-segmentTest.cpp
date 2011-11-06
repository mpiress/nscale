/*
 * test.cpp
 *
 *  Created on: Jun 28, 2011
 *      Author: tcpan
 */
#include "opencv2/opencv.hpp"
#include "opencv2/gpu/gpu.hpp"
#include "highgui.h"
#include <iostream>
#include <vector>
#include <string>
#include "HistologicalEntities.h"
#include "MorphologicOperations.h"
#include "utils.h"
#include "FileUtils.h"
#include <dirent.h>

#ifdef _OPENMP
#include <omp.h>
#endif

#ifdef WITH_MPI
#include <mpi.h>
#endif

using namespace cv;


int main (int argc, char **argv){
#ifdef WITH_MPI
    MPI::Init(argc, argv);
    int size = MPI::COMM_WORLD.Get_size();
    int rank = MPI::COMM_WORLD.Get_rank();
    printf( " MPI enabled: rank %d \n", rank);
#else
    int size = 1;
    int rank = 0;
    printf( " MPI disabled\n");
#endif

    // relevant to head node only
    std::vector<std::string> filenames;
	std::vector<std::string> seg_output;
	std::vector<std::string> bounds_output;
	char *inputBufAll, *maskBufAll, *boundsBufAll;
	inputBufAll=NULL;
	maskBufAll=NULL;
	boundsBufAll=NULL;
	int dataCount;

	// relevant to all nodes
	int modecode = 0;
	uint64_t t1 = 0, t2 = 0, t3 = 0, t4 = 0;
	std::string fin, fmask, fbound;
	unsigned int perNodeCount=0, maxLenInput=0, maxLenMask=0, maxLenBounds=0;
	char *inputBuf, *maskBuf, *boundsBuf;
	inputBuf=NULL;
	maskBuf=NULL;
	boundsBuf=NULL;

	if (argc < 6) {
		std::cout << "Usage:  " << argv[0] << " <image_filename | image_dir> mask_dir " << "run-id minstage maxstage [cpu [numThreads] | mcore [numThreads] | gpu [id]]" << std::endl;
		return -1;
	}
	std::string imagename(argv[1]);
	std::string outDir(argv[2]);
	int mins = atoi(argv[4]);
	int maxs = atoi(argv[5]);
	const char* mode = argc > 6 ? argv[6] : "cpu";

	if (strcasecmp(mode, "cpu") == 0) {
		modecode = cciutils::DEVICE_CPU;
		// get core count

#ifdef _OPENMP
		if (argc > 7) {
			omp_set_num_threads(atoi(argv[7]) > omp_get_max_threads() ? omp_get_max_threads() : atoi(argv[7]));
			printf("number of threads used = %d\n", omp_get_num_threads());
		}
#endif
	} else if (strcasecmp(mode, "mcore") == 0) {
		modecode = cciutils::DEVICE_MCORE;
		// get core count
#ifdef _OPENMP
		if (argc > 7) {
			omp_set_num_threads(atoi(argv[7]) > omp_get_max_threads() ? omp_get_max_threads() : atoi(argv[7]));
			printf("number of threads used = %d\n", omp_get_num_threads());
		}
#endif
	} else if (strcasecmp(mode, "gpu") == 0) {
		modecode = cciutils::DEVICE_GPU;
		// get device count
		int numGPU = gpu::getCudaEnabledDeviceCount();
		if (numGPU < 1) {
			printf("gpu requested, but no gpu available.  please use cpu or mcore option.\n");
			return -2;
		}
		if (argc > 7) {
			gpu::setDevice(atoi(argv[7]));
		}
		printf(" number of cuda enabled devices = %d\n", gpu::getCudaEnabledDeviceCount());
	} else {
		std::cout << "Usage:  " << argv[0] << " <image_filename | image_dir> mask_dir " << "run-id minstage maxstage [cpu [numThreads] | mcore [numThreads] | gpu [id]]" << std::endl;
		return -1;
	}

	if (rank == 0) {
		// check to see if it's a directory or a file
		std::string suffix;
		suffix.assign(".tif");

		FileUtils futils(suffix);
		futils.traverseDirectoryRecursive(imagename, filenames);
		std::string dirname;
		if (filenames.size() == 1) {
			dirname = filenames[0].substr(0, filenames[0].find_last_of("/\\"));
		} else {
			dirname = imagename;
		}


		std::string temp, tempdir;
		for (unsigned int i = 0; i < filenames.size(); ++i) {
			maxLenInput = maxLenInput > filenames[i].length() ? maxLenInput : filenames[i].length();
				// generate the output file name
			temp = futils.replaceExt(filenames[i], ".tif", ".mask.pbm");
			temp = futils.replaceDir(temp, dirname, outDir);
			tempdir = temp.substr(0, temp.find_last_of("/\\"));
			futils.mkdirs(tempdir);
			seg_output.push_back(temp);
			maxLenMask = maxLenMask > temp.length() ? maxLenMask : temp.length();
			// generate the bounds output file name
			temp = futils.replaceExt(filenames[i], ".tif", ".bounds.csv");
			temp = futils.replaceDir(temp, dirname, outDir);
			tempdir = temp.substr(0, temp.find_last_of("/\\"));
			futils.mkdirs(tempdir);
			bounds_output.push_back(temp);
			maxLenBounds = maxLenBounds > temp.length() ? maxLenBounds : temp.length();
		}
		dataCount= filenames.size();
	}

#ifdef WITH_MPI
	if (rank == 0) {
		perNodeCount = filenames.size() / size + (filenames.size() % size == 0 ? 0 : 1);

		printf("headnode: rank is %d here.  perNodeCount is %d, outputLen %d, inputLen %d \n", rank, perNodeCount, maxLenMask, maxLenInput);

		// allocate the sendbuffer
		inputBufAll= (char*)malloc(perNodeCount * size * maxLenInput * sizeof(char));
		maskBufAll= (char*)malloc(perNodeCount * size * maxLenMask * sizeof(char));
		boundsBufAll= (char*)malloc(perNodeCount * size * maxLenBounds * sizeof(char));
		memset(inputBufAll, 0, perNodeCount * size * maxLenInput);
		memset(maskBufAll, 0, perNodeCount * size * maxLenMask);
		memset(boundsBufAll, 0, perNodeCount * size * maxLenBounds);

		// copy data into the buffers
		for (unsigned int i = 0; i < filenames.size(); ++i) {
			strncpy(inputBufAll + i * maxLenInput, filenames[i].c_str(), maxLenInput);
			strncpy(maskBufAll + i * maxLenMask, seg_output[i].c_str(), maxLenMask);
			strncpy(boundsBufAll + i * maxLenBounds, bounds_output[i].c_str(), maxLenBounds);

		}
	}
//	printf("rank: %d\n ", rank);
	MPI::COMM_WORLD.Barrier();

	MPI::COMM_WORLD.Bcast(&perNodeCount, 1, MPI::INT, 0);
	MPI::COMM_WORLD.Bcast(&maxLenInput, 1, MPI::INT, 0);
	MPI::COMM_WORLD.Bcast(&maxLenMask, 1, MPI::INT, 0);
	MPI::COMM_WORLD.Bcast(&maxLenBounds, 1, MPI::INT, 0);


//	printf("rank is %d here.  perNodeCount is %d, outputLen %d, inputLen %d \n", rank, perNodeCount, maxLenMask, maxLenInput);

	// allocate the receive buffer
	inputBuf = (char*)malloc(perNodeCount * maxLenInput * sizeof(char));
	maskBuf = (char*)malloc(perNodeCount * maxLenMask * sizeof(char));
	boundsBuf = (char*)malloc(perNodeCount * maxLenBounds * sizeof(char));

	// scatter
	MPI::COMM_WORLD.Scatter(inputBufAll, perNodeCount * maxLenInput, MPI::CHAR,
		inputBuf, perNodeCount * maxLenInput, MPI::CHAR,
		0);

	MPI::COMM_WORLD.Scatter(maskBufAll, perNodeCount * maxLenMask, MPI::CHAR,
		maskBuf, perNodeCount * maxLenMask, MPI::CHAR,
		0);

	MPI::COMM_WORLD.Scatter(boundsBufAll, perNodeCount * maxLenBounds, MPI::CHAR,
		boundsBuf, perNodeCount * maxLenBounds, MPI::CHAR,
		0);

#endif

	if (rank == 0) {
		t3 = cciutils::ClockGetTime();
	} // end if (rank == 0)


#ifdef WITH_MPI
#pragma omp parallel for shared(perNodeCount, inputBuf, maskBuf, boundsBuf, maxLenInput, maxLenMask, maxLenBounds, modecode, rank, mins, maxs) private(fin, fmask, fbound, t1, t2)
    for (unsigned int i = 0; i < perNodeCount; ++i) {
		fin = std::string(inputBuf + i * maxLenInput, maxLenInput);
		fmask = std::string(maskBuf + i * maxLenMask, maxLenMask);
		fbound = std::string(boundsBuf + i * maxLenBounds, maxLenBounds);
#else
#pragma omp parallel for shared(filenames, seg_output, bounds_output, modecode, rank, mins, maxs) private(fin, fmask, fbound, t1, t2)
    for (unsigned int i = 0; i < dataCount; ++i) {
		fin = filenames[i];
		fmask = seg_output[i];
		fbound = bounds_output[i];
//		printf("in seq seg loop with rank %d, loop %d\n", rank, i);
#endif

#ifdef _OPENMP
    	int tid = omp_get_thread_num();
#else
		int tid = 0;
#endif

//  	std::cout << outfile << std::endl;

		t1 = cciutils::ClockGetTime();

		int status;
		FileUtils fu(".mask.pbm");
		for (int stage = mins; stage <= maxs; ++stage) {
			char prefix[80];
		    sprintf(prefix, "-%d%s", stage, ".mask.pbm");
		    std::string temp = fu.replaceExt(fmask, ".mask.pbm", prefix);;

			switch (modecode) {
			case cciutils::DEVICE_CPU :
			case cciutils::DEVICE_MCORE :
				status = nscale::HistologicalEntities::segmentNuclei(fin, temp, NULL, stage);
				break;
			case cciutils::DEVICE_GPU :
				status = nscale::gpu::HistologicalEntities::segmentNuclei(fin, temp, NULL, stage);
				break;
			default :
				break;
			}
		}

		if (status != nscale::HistologicalEntities::SUCCESS) {
#ifdef WITH_MPI
			memset(maskBuf + i * maxLenMask, 0, maxLenMask);
#else
			seg_output[i] = std::string("");
#endif
		}
		t2 = cciutils::ClockGetTime();
		printf("%d::%d: segment %lu us, in %s\n", rank, tid, t2-t1, fin.c_str());
//		std::cout << rank <<"::" << tid << ":" << t2-t1 << " us, in " << fin << ", out " << fmask << std::endl;

    }

#ifdef WITH_MPI
    MPI::COMM_WORLD.Barrier();
#endif
    if (rank == 0)  {
    	t4 = cciutils::ClockGetTime();
		printf("**** Segment took %lu us\n", t4-t3);
	//	std::cout << "**** Segment took " << t4-t3 << " us" << std::endl;

		t3 = cciutils::ClockGetTime();
    }

#ifdef WITH_MPI
    if (rank == 0) {
		free(inputBufAll);
		free(maskBufAll);
		free(boundsBufAll);
    }

	free(inputBuf);
	free(maskBuf);
	free(boundsBuf);

	MPI::Finalize();
#endif


//	waitKey();

	return 0;
}


