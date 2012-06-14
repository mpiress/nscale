/*
 * test.cpp
 *
 *  Created on: Jun 28, 2011
 *      Author: tcpan
 */
#include "opencv2/opencv.hpp"
#include <iostream>
#include <dirent.h>
#include <vector>
#include <errno.h>
#include <time.h>
#include "MorphologicOperations.h"
#include "utils.h"
#include <stdio.h>
#include <omp.h>

#include "opencv2/gpu/gpu.hpp"



using namespace cv;
using namespace cv::gpu;
using namespace std;

int main (int argc, char **argv){
	if(argc != 3){
		std::cout << "Usage: ./imreconMulticore <marker-img> <mask-img>" <<std::endl;
		exit(1);
	}
	Mat marker = imread(argv[1], -1);
	Mat mask = imread(argv[2], -1);

	Mat marker_copy, mask_copy;
	marker.copyTo(marker_copy);
	mask.copyTo(mask_copy);

	
	Mat recon, recon2;
	uint64_t t1, t2;

	int tileWidth=2048;
	int tileHeight=2048;
	int nTilesX=marker.cols/tileWidth;
	int nTilesY=marker.rows/tileHeight;
	
	uint64_t t1_tiled = cciutils::ClockGetTime();
//omp_set_num_threads(int num_threads)

#pragma omp parallel for
	for(int tileY=0; tileY < nTilesY; tileY++){
#pragma omp parallel for
		for(int tileX=0; tileX < nTilesX; tileX++){
//			std::cout <<"Rect("<< tileX*tileWidth << "," << tileY*tileHeight <<","<< tileWidth <<","<< tileHeight<< ");"<<std::endl;
			Mat roiMarker(marker_copy, Rect(tileX*tileWidth, tileY*tileHeight , tileWidth, tileHeight ));
			Mat roiMask(mask_copy, Rect(tileX*tileWidth, tileY*tileHeight , tileWidth, tileHeight));
			
			t1 = cciutils::ClockGetTime();
			Mat reconTile = nscale::imreconstruct<unsigned char>(roiMarker, roiMask, 8);
			reconTile.copyTo(roiMarker);
			t2 = cciutils::ClockGetTime();

			std::cout << " Tile took " << t2-t1 << "ms" << std::endl;
		}
	}
	uint64_t t2_tiled = cciutils::ClockGetTime();
	std::cout << " Tile total took " << t2_tiled-t1_tiled << "ms" << std::endl;

	t1 = cciutils::ClockGetTime();
	Mat reconCopy = nscale::imreconstructFixTilingEffects<unsigned char>(marker_copy, mask, 8, 0, 0, tileWidth);
	t2 = cciutils::ClockGetTime();
	std::cout << "fix tiling recon8 took " << t2-t1 << "ms" << std::endl;


	t1 = cciutils::ClockGetTime();
	recon = nscale::imreconstruct<unsigned char>(marker, mask, 8);
	t2 = cciutils::ClockGetTime();
	std::cout << " cpu recon8 took " << t2-t1 << "ms" << std::endl;
	imwrite("out-recon8.ppm", recon);
	imwrite("out-recon8tile.ppm", marker_copy);



	Mat comp = recon != reconCopy;

	std::cout << "comp reconCopy= "<<countNonZero(comp) << std::endl;

	imwrite("diff.ppm", comp);
	return 0;
}
