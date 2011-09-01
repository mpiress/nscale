// adaptation of Pavel's imreconstruction code for openCV

#include "internal_shared.hpp"
#include "change_kernel.cuh"

#define MAX_THREADS			64
#define X_THREADS			8
#define Y_THREADS			8
#define NEQ(a,b)    ( (a) != (b) )


using namespace cv::gpu;


namespace nscale { namespace gpu {


////////////////////////////////////////////////////////////////////////////////
// RECONSTRUCTION BY DILATION
////////////////////////////////////////////////////////////////////////////////
/*
 * original code
 */
template <typename T>
__global__ void
fRec1DForward_X_dilation2 ( DevMem2D_<T> g_marker, DevMem2D_<T> g_mask, bool* change )
{

	const int ty = threadIdx.y;
	const int by = blockIdx.y * Y_THREADS;
	const int sx = g_marker.cols;
	const int sy = g_marker.rows;

	if (ty + by < sy) {

		__shared__ T s_marker[Y_THREADS][Y_THREADS];
		__shared__ T s_mask  [Y_THREADS][Y_THREADS];
		__shared__ bool  s_change[Y_THREADS][Y_THREADS];
		T* marker = g_marker.ptr(by + ty);
		T* mask = g_mask.ptr(by + ty);
		int ix, startx;
		for (ix = 0; ix < Y_THREADS; ix++) {
			s_change[ix][ty] = false;
		}
		__syncthreads();

		T s_old;
		// the increment allows overlap by 1 between iterations to move the data to next block.
		for (startx = 0; startx < sx - Y_THREADS; startx += Y_THREADS - 1) {

			// copy part of marker and mask to shared memory
			for (ix = 0; ix < Y_THREADS; ix++) {
				s_marker[ix][ty] = marker[startx + ix];
				s_mask  [ix][ty] = mask  [startx + ix];
			}
			__syncthreads();

			// perform iteration   all X threads do the same operations, so there may be read/write hazards.  but the output is the same.
			// this is looping for BLOCK_SIZE times, and each iteration the final results are propagated 1 step closer to tx.
			for (ix = 1; ix < Y_THREADS; ix++) {
				s_old = s_marker[ix][ty];
				s_marker[ix][ty] = fmaxf( s_marker[ix][ty], s_marker[ix-1][ty] );
				s_marker[ix][ty] = fminf( s_marker[ix][ty], s_mask  [ix]  [ty] );
				s_change[ix][ty] |= NEQ( s_old, s_marker[ix][ty] );
				__syncthreads();
			}

			// output result back to global memory
			for (ix = 0; ix < Y_THREADS; ix++) {
				marker[startx + ix] = s_marker[ix][ty];
			}
			__syncthreads();

		}

		startx = sx - Y_THREADS;

		// copy part of marker and mask to shared memory
		for (ix = 0; ix < Y_THREADS; ix++) {
			s_marker[ix][ty] = marker[ startx + ix ];
			s_mask  [ix][ty] = mask  [ startx + ix ];
		}
		__syncthreads();

		// perform iteration
		for (ix = 1; ix < Y_THREADS; ix++) {
			s_old = s_marker[ix][ty];
			s_marker[ix][ty] = fmaxf( s_marker[ix][ty], s_marker[ix-1][ty] );
			s_marker[ix][ty] = fminf( s_marker[ix][ty], s_mask  [ix]  [ty] );
			s_change[ix][ty] |= NEQ( s_old, s_marker[ix][ty] );
			__syncthreads();
		}

		// output result back to global memory
		for (ix = 0; ix < Y_THREADS; ix++) {
			marker[ startx + ix ] = s_marker[ix][ty];
			if (s_change[ix][ty]) *change = true;
		}
		__syncthreads();

	}

}

template <typename T>
__global__ void
fRec1DBackward_X_dilation2 ( DevMem2D_<T> g_marker, DevMem2D_<T> g_mask, bool* change )
{

	const int ty = threadIdx.y;
	const int by = blockIdx.y * Y_THREADS;
	// always 0.  const int bz = blockIdx.y;
	const int sx = g_marker.cols;
	const int sy = g_marker.rows;


	if (by + ty < sy) {

		__shared__ T s_marker[Y_THREADS][Y_THREADS];
		__shared__ T s_mask  [Y_THREADS][Y_THREADS];
		__shared__ bool  s_change[Y_THREADS][Y_THREADS];
		T* marker = g_marker.ptr(by + ty);
		T* mask = g_mask.ptr(by + ty);
		int ix, startx;
		for (ix = 0; ix < Y_THREADS; ix++) {
			s_change[ix][ty] = false;
		}
		__syncthreads();

		T s_old;
		for (startx = sx - Y_THREADS; startx > 0; startx -= Y_THREADS - 1) {

			// copy part of marker and mask to shared memory
			for (ix = 0; ix < Y_THREADS; ix++) {
				s_marker[ix][ty] = marker[ startx + ix ];
				s_mask  [ix][ty] = mask  [ startx + ix ];
			}
			__syncthreads();

			// perform iteration
			for (ix = Y_THREADS - 2; ix >= 0; ix--) {
				s_old = s_marker[ix][ty];
				s_marker[ix][ty] = fmaxf( s_marker[ix][ty], s_marker[ix+1][ty] );
				s_marker[ix][ty] = fminf( s_marker[ix][ty], s_mask  [ix]  [ty] );
				s_change[ix][ty] |= NEQ( s_old, s_marker[ix][ty] );
				__syncthreads();
			}

			// output result back to global memory
			for (ix = 0; ix < Y_THREADS; ix++) {
				marker[ startx + ix ] = s_marker[ix][ty];
			}
			__syncthreads();

		}

		startx = 0;

		// copy part of marker and mask to shared memory
		for (ix = 0; ix < Y_THREADS; ix++) {
			s_marker[ix][ty] = marker[ startx + ix ];
			s_mask  [ix][ty] = mask  [ startx + ix ];
		}
		__syncthreads();

		// perform iteration
		for (ix = Y_THREADS - 2; ix >= 0; ix--) {
			s_old = s_marker[ix][ty];
			s_marker[ix][ty] = fmaxf( s_marker[ix][ty], s_marker[ix+1][ty] );
			s_marker[ix][ty] = fminf( s_marker[ix][ty], s_mask  [ix]  [ty] );
			s_change[ix][ty] |= NEQ( s_old, s_marker[ix][ty] );
			__syncthreads();
		}

		// output result back to global memory
		for (ix = 0; ix < Y_THREADS; ix++) {
			marker[ startx + ix ] = s_marker[ix][ty];
			if (s_change[ix][ty]) *change = true;
		}
		__syncthreads();


	}

}

////////////////////////////////////////////////////////////////////////////////
// RECONSTRUCTION BY DILATION
////////////////////////////////////////////////////////////////////////////////
/*
 * original code
 */
template <typename T>
__global__ void
fRec1DForward_X_dilation ( DevMem2D_<T> g_marker, DevMem2D_<T> g_mask, bool* change )
{

	const int tx = threadIdx.x;
	const int ty = threadIdx.y;
	const int by = blockIdx.y * Y_THREADS;
	const int sx = g_marker.cols;
	const int sy = g_marker.rows;

	if (ty + by < sy) {

		__shared__ T s_marker[X_THREADS][Y_THREADS];
		__shared__ T s_mask  [X_THREADS][Y_THREADS];
		__shared__ bool  s_change[X_THREADS][Y_THREADS];
		T* marker = g_marker.ptr(by + ty)+ tx;
		T* mask = g_mask.ptr(by + ty)+ tx;
		s_change[tx][ty] = false;
		__syncthreads();

		T s_old;
		int ix, startx;
		// the increment allows overlap by 1 between iterations to move the data to next block.
		for (startx = 0; startx < sx - X_THREADS; startx += X_THREADS - 1) {

			// copy part of marker and mask to shared memory
			s_marker[tx][ty] = marker[startx];
			s_mask  [tx][ty] = mask  [startx];
			__syncthreads();

			// perform iteration   all X threads do the same operations, so there may be read/write hazards.  but the output is the same.
			// this is looping for BLOCK_SIZE times, and each iteration the final results are propagated 1 step closer to tx.
			for (ix = 1; ix < X_THREADS; ix++) {
				s_old = s_marker[ix][ty];
				s_marker[ix][ty] = fmaxf( s_marker[ix][ty], s_marker[ix-1][ty] );
				s_marker[ix][ty] = fminf( s_marker[ix][ty], s_mask  [ix]  [ty] );
				s_change[ix][ty] |= NEQ( s_old, s_marker[ix][ty] );
				__syncthreads();
			}

			// output result back to global memory
			marker[startx] = s_marker[tx][ty];
			__syncthreads();

		}

		startx = sx - X_THREADS;

		// copy part of marker and mask to shared memory
		s_marker[tx][ty] = marker[ startx ];
		s_mask  [tx][ty] = mask  [ startx ];
		__syncthreads();

		// perform iteration
		for (ix = 1; ix < X_THREADS; ix++) {
			s_old = s_marker[ix][ty];
			s_marker[ix][ty] = fmaxf( s_marker[ix][ty], s_marker[ix-1][ty] );
			s_marker[ix][ty] = fminf( s_marker[ix][ty], s_mask  [ix]  [ty] );
			s_change[ix][ty] |= NEQ( s_old, s_marker[ix][ty] );
			__syncthreads();
		}

		// output result back to global memory
		marker[ startx ] = s_marker[tx][ty];
		__syncthreads();

		if (s_change[tx][ty]) *change = true;
		__syncthreads();

	}

}

template <typename T>
__global__ void
fRec1DBackward_X_dilation ( DevMem2D_<T> g_marker, DevMem2D_<T> g_mask, bool* change )
{

	const int tx = threadIdx.x;
	const int ty = threadIdx.y;
	const int by = blockIdx.y * Y_THREADS;
	// always 0.  const int bz = blockIdx.y;
	const int sx = g_marker.cols;
	const int sy = g_marker.rows;

	
	if (by + ty < sy) {

		__shared__ T s_marker[X_THREADS][Y_THREADS];
		__shared__ T s_mask  [X_THREADS][Y_THREADS];
		__shared__ bool  s_change[X_THREADS][Y_THREADS];
		T* marker = g_marker.ptr(by + ty) + tx;
		T* mask = g_mask.ptr(by + ty) + tx;
		s_change[tx][ty] = false;
		__syncthreads();

		T s_old;
		int ix, startx;
		for (startx = sx - X_THREADS; startx > 0; startx -= X_THREADS - 1) {

			// copy part of marker and mask to shared memory
			s_marker[tx][ty] = marker[ startx ];
			s_mask  [tx][ty] = mask  [ startx ];
			__syncthreads();

			// perform iteration
			for (ix = X_THREADS - 2; ix >= 0; ix--) {
				s_old = s_marker[ix][ty];
				s_marker[ix][ty] = fmaxf( s_marker[ix][ty], s_marker[ix+1][ty] );
				s_marker[ix][ty] = fminf( s_marker[ix][ty], s_mask  [ix]  [ty] );
				s_change[ix][ty] |= NEQ( s_old, s_marker[ix][ty] );
				__syncthreads();
			}

			// output result back to global memory
			marker[ startx ] = s_marker[tx][ty];
			__syncthreads();

		}

		startx = 0;

		// copy part of marker and mask to shared memory
		s_marker[tx][ty] = marker[ startx ];
		s_mask  [tx][ty] = mask  [ startx ];
		__syncthreads();

		// perform iteration
		for (ix = X_THREADS - 2; ix >= 0; ix--) {
			s_old = s_marker[ix][ty];
			s_marker[ix][ty] = fmaxf( s_marker[ix][ty], s_marker[ix+1][ty] );
			s_marker[ix][ty] = fminf( s_marker[ix][ty], s_mask  [ix]  [ty] );
			s_change[ix][ty] |= NEQ( s_old, s_marker[ix][ty] );
			__syncthreads();
		}

		// output result back to global memory
		marker[ startx ] = s_marker[tx][ty];
		__syncthreads();
		
		if (s_change[tx][ty]) *change = true;
		__syncthreads();

	}

}


/*
template <typename T>
__global__ void
fRec1D8ConnectedWindowedMax ( DevMem2D_<T> g_marker_max, DevMem2D_<T> g_marker)
{
	// parallelize along y.
	const int ty = threadIdx.y;
	const int by = blockIdx.y * MAX_THREADS;
	const int sx = g_marker.cols;
	const int sy = g_marker.rows;
	int y = by + ty;
	
	if ( (by + ty) < sy) {
		__shared__ T s_marker[MAX_THREADS][3];
		__shared__ T s_out[MAX_THREADS];
		T temp;
		T* marker = g_marker.ptr(y);
		T* output = g_marker_max.ptr(y);
		s_marker[ty][0] = 0;
		s_marker[ty][1] = *marker;
		__syncthreads();
		
		for (ix = 0; ix < (sx - 1); ix++) {
			s_marker[ty][2] = marker[ix + 1];
			__syncthreads;
			
			temp = fmaxf(s_marker[ty][0], s_marker[ty][1]);
			s_out[ty] = fmaxf(temp, s_marker[ty][2]);
						
			s_marker[ty][0] = s_marker[ty][1];
			s_marker[ty][1] = s_marker[ty][2];
			__syncthreads();
			
			output[ix] = s_out[ty];
			__syncthreads();
		}
		
		// do the last one
		s_out[ty] = fmaxf(s_marker[ty][0], s_marker[ty][1]);
		__syncthreads();
		
		output[sx-1] = s_out[ty];
		__syncthreads();
	}

} 
*/


template <typename T>
__global__ void
fRec1DForward_Y_dilation ( DevMem2D_<T> g_marker, DevMem2D_<T> g_mask, bool* change )
{
	// parallelize along x.
	const int tx = threadIdx.x;
	const int bx = blockIdx.x * MAX_THREADS;
	const int sx = g_marker.cols;
	const int sy = g_marker.rows;
	const int marker_step = g_marker.step;
	const int mask_step = g_mask.step;
	
	if ( (bx + tx) < sx ) {

		__shared__ T s_marker_A[MAX_THREADS];
		__shared__ T s_marker_B[MAX_THREADS];
		__shared__ T s_mask    [MAX_THREADS];
		__shared__ bool  s_change  [MAX_THREADS];
		T* marker = g_marker.ptr(0) + bx + tx;
		T* mask = g_mask.ptr(0) + bx + tx;
		s_change[tx] = false;
		s_marker_B[tx] = *marker;
		__syncthreads();

		T s_old;
		for (int ty = 1; ty < sy; ty++) {
			marker += marker_step;
			mask += mask_step;
		
			// copy part of marker and mask to shared memory
			s_marker_A[tx] = s_marker_B[tx];
			s_marker_B[tx] = *marker;
			s_mask    [tx] = *mask;
			__syncthreads();

			// perform iteration
			s_old = s_marker_B[tx];
			s_marker_B[tx] = fmaxf( s_marker_A[tx], s_marker_B[tx] );
			s_marker_B[tx] = fminf( s_marker_B[tx], s_mask    [tx] );
			s_change[tx] |= NEQ( s_old, s_marker_B[tx] );
			__syncthreads();

			// output result back to global memory
			*marker = s_marker_B[tx];
			__syncthreads();

		}

		if (s_change[tx]) *change = true;
		__syncthreads();

	}

}

template <typename T>
__global__ void
fRec1DBackward_Y_dilation ( DevMem2D_<T> g_marker, DevMem2D_<T> g_mask, bool* change )
{

	const int tx = threadIdx.x;
	const int bx = blockIdx.x * MAX_THREADS;
	const int sx = g_marker.cols;
	const int sy = g_marker.rows;
	const int marker_step = g_marker.step;
	const int mask_step = g_mask.step;

	if ( (bx + tx) < sx ) {

		__shared__ T s_marker_A[MAX_THREADS];
		__shared__ T s_marker_B[MAX_THREADS];
		__shared__ T s_mask    [MAX_THREADS];
		__shared__ bool  s_change  [MAX_THREADS];
		T* marker = g_marker.ptr(sy-1) + bx + tx;
		T* mask = g_mask.ptr(sy-1) + bx + tx;
		s_change[tx] = false;
		s_marker_B[tx] = *marker;
		__syncthreads();

		T s_old;
		for (int ty = sy - 2; ty >= 0; ty--) {
			marker -= marker_step;
			mask -= mask_step;

			// copy part of marker and mask to shared memory
			s_marker_A[tx] = s_marker_B[tx];
			s_marker_B[tx] = *marker;
			s_mask    [tx] = *mask;
			__syncthreads();

			// perform iteration
			s_old = s_marker_B[tx];
			s_marker_B[tx] = fmaxf( s_marker_A[tx], s_marker_B[tx] );
			s_marker_B[tx] = fminf( s_marker_B[tx], s_mask    [tx] );
			s_change[tx] |= NEQ( s_old, s_marker_B[tx] );
			__syncthreads();

			// output result back to global memory
			*marker = s_marker_B[tx];
			__syncthreads();

		}

		if (s_change[tx]) *change = true;
		__syncthreads();

	}

}

// 8 conn...
//overlap:  tx 0 to 7 maps to -1 to 6, with usable from 0 to 5.  output for 6-11, from 5 - 12
//formula:  bx * (block-2) - 1 + tx = startx in src data.
//formula:  


template <typename T>
__global__ void
fRec1DForward_Y_dilation_8 ( DevMem2D_<T> g_marker, DevMem2D_<T> g_mask, bool* change )
{
	// parallelize along x.
	const int tx = threadIdx.x;
	const int bx = blockIdx.x * (MAX_THREADS - 2) - 1;
	const int sx = g_marker.cols;
	const int sy = g_marker.rows;
	const int marker_step = g_marker.step;
	const int mask_step = g_mask.step;
	int x = bx+tx;
	
	if ( x >= 0 && x < sx ) {

		__shared__ T s_marker_A[MAX_THREADS];
		__shared__ T s_marker_B[MAX_THREADS];
		__shared__ T s_mask    [MAX_THREADS];
		__shared__ bool  s_change  [MAX_THREADS];
		T* marker = g_marker.ptr(0) + x;
		T* mask = g_mask.ptr(0) + x;
		s_change[tx] = false;
		s_marker_B[tx] = *marker;
		__syncthreads();

		T s_old;
		for (int ty = 1; ty < sy; ty++) {
			marker += marker_step;
			mask += mask_step;
		
			// copy part of marker and mask to shared memory
			s_marker_A[tx] = s_marker_B[tx];
			s_marker_B[tx] = *marker;
			s_mask    [tx] = *mask;
			__syncthreads();

			// perform iteration
			if (tx > 0 && tx < MAX_THREADS - 1) {
				s_old = s_marker_B[tx];
				s_marker_B[tx] = fmaxf( s_marker_A[tx], s_marker_B[tx] );
				s_marker_B[tx] = fmaxf( s_marker_A[tx-1], s_marker_B[tx] );
				s_marker_B[tx] = fmaxf( s_marker_A[tx+1], s_marker_B[tx] );
				s_marker_B[tx] = fminf( s_marker_B[tx], s_mask    [tx] );
				s_change[tx] |= NEQ( s_old, s_marker_B[tx] );
				// output result back to global memory
				*marker = s_marker_B[tx];
			}
			__syncthreads();
		}

		if (tx > 0 && tx < MAX_THREADS - 1) {
			if (s_change[tx]) *change = true;
		}
		__syncthreads();
	}
}

template <typename T>
__global__ void
fRec1DBackward_Y_dilation_8 ( DevMem2D_<T> g_marker, DevMem2D_<T> g_mask, bool* change )
{

	const int tx = threadIdx.x;
	const int bx = blockIdx.x * (MAX_THREADS - 2) - 1;
	const int sx = g_marker.cols;
	const int sy = g_marker.rows;
	const int marker_step = g_marker.step;
	const int mask_step = g_mask.step;
	int x = bx+ tx;

	if ( x >= 0 && x < sx ) {

		__shared__ T s_marker_A[MAX_THREADS];
		__shared__ T s_marker_B[MAX_THREADS];
		__shared__ T s_mask    [MAX_THREADS];
		__shared__ bool  s_change  [MAX_THREADS];
		T* marker = g_marker.ptr(sy-1) + x;
		T* mask = g_mask.ptr(sy-1) + x;
		s_change[tx] = false;
		s_marker_B[tx] = *marker;
		__syncthreads();

		T s_old;
		for (int ty = sy - 2; ty >= 0; ty--) {
			marker -= marker_step;
			mask -= mask_step;

			// copy part of marker and mask to shared memory
			s_marker_A[tx] = s_marker_B[tx];
			s_marker_B[tx] = *marker;
			s_mask    [tx] = *mask;
			__syncthreads();

			// perform iteration
			if (tx > 0 && tx < MAX_THREADS - 1) {
				s_old = s_marker_B[tx];
				s_marker_B[tx] = fmaxf( s_marker_A[tx], s_marker_B[tx] );
				s_marker_B[tx] = fmaxf( s_marker_A[tx-1], s_marker_B[tx] );
				s_marker_B[tx] = fmaxf( s_marker_A[tx+1], s_marker_B[tx] );
				s_marker_B[tx] = fminf( s_marker_B[tx], s_mask    [tx] );
				s_change[tx] |= NEQ( s_old, s_marker_B[tx] );
				// output result back to global memory
				*marker = s_marker_B[tx];
			}
			__syncthreads();


		}

		if (tx > 0 && tx < MAX_THREADS - 1) {
			if (s_change[tx]) *change = true;
		}
		__syncthreads();

	}

}


	// connectivity:  if 8 conn, need to have border.

	template <typename T>
	void imreconstructFloatCaller(DevMem2D_<T> marker, const DevMem2D_<T> mask,
		int connectivity, cudaStream_t stream) {


		// here because we are not using streams inside.
		if (stream == 0) cudaSafeCall(cudaDeviceSynchronize());
		else cudaSafeCall( cudaStreamSynchronize(stream));

		printf("entering imrecon float caller with conn=%d\n", connectivity);
		// setup execution parameters
		int sx = marker.cols;
		int sy = marker.rows;
		bool conn8 = (connectivity == 8);
		int bx;
		if (conn8) {
			int block_size_x = MAX_THREADS - 2;
			bx = (sx-2)/block_size_x + ( ((sx-2) % block_size_x == 0) ? 0 : 1 );
		} else {
			bx = sx/MAX_THREADS + ( (sx % MAX_THREADS == 0) ? 0 : 1 );
		}
		int by = sy/Y_THREADS + ( (sy % Y_THREADS == 0) ? 0 : 1 );

		dim3 blocksx( 1, by );
		dim3 threadsx( X_THREADS, Y_THREADS );
		dim3 threadsx2( 1, Y_THREADS );
		dim3 blocksy( bx, 1 );
		dim3 threadsy( MAX_THREADS );

		// stability detection
		unsigned int iter = 0;
		bool *h_change, *d_change;
		h_change = (bool*) malloc( sizeof(bool) );
		cudaSafeCall( cudaMalloc( (void**) &d_change, sizeof(bool) ) );
		
		*h_change = true;
		printf("completed setup for imrecon binary caller \n");

		if (conn8) {
			while ( (*h_change) && (iter < 100000) )  // repeat until stability
			{
				iter++;
				*h_change = false;
				init_change<<< 1, 1>>>( d_change );

				// dopredny pruchod pres osu X
				fRec1DForward_X_dilation <<< blocksx, threadsx >>> ( marker, mask, d_change );
				//fRec1DForward_X_dilation2<<< blocksx, threadsx2, 0, stream >>> ( marker, mask, d_change );

				// dopredny pruchod pres osu Y
				fRec1DForward_Y_dilation_8<<< blocksy, threadsy >>> ( marker, mask, d_change );

				// zpetny pruchod pres osu X
				fRec1DBackward_X_dilation<<< blocksx, threadsx >>> ( marker, mask, d_change );
				//fRec1DBackward_X_dilation2<<< blocksx, threadsx2, 0, stream >>> ( marker, mask, d_change );

				// zpetny pruchod pres osu Y
				fRec1DBackward_Y_dilation_8<<< blocksy, threadsy >>> ( marker, mask, d_change );

//				if (stream == 0) cudaSafeCall(cudaDeviceSynchronize());
//				else cudaSafeCall( cudaStreamSynchronize(stream));

				cudaSafeCall( cudaMemcpy( h_change, d_change, sizeof(bool), cudaMemcpyDeviceToHost ) );

			}
		} else {
			while ( (*h_change) && (iter < 100000) )  // repeat until stability
			{
				iter++;
				*h_change = false;
				init_change<<< 1, 1>>>( d_change );

				// dopredny pruchod pres osu X
				fRec1DForward_X_dilation <<< blocksx, threadsx >>> ( marker, mask, d_change );
				//fRec1DForward_X_dilation2<<< blocksx, threadsx2, 0, stream >>> ( marker, mask, d_change );

				// dopredny pruchod pres osu Y
				fRec1DForward_Y_dilation <<< blocksy, threadsy >>> ( marker, mask, d_change );

				// zpetny pruchod pres osu X
				fRec1DBackward_X_dilation<<< blocksx, threadsx >>> ( marker, mask, d_change );
				//fRec1DBackward_X_dilation2<<< blocksx, threadsx2, 0, stream >>> ( marker, mask, d_change );

				// zpetny pruchod pres osu Y
				fRec1DBackward_Y_dilation<<< blocksy, threadsy >>> ( marker, mask, d_change );

//				if (stream == 0) cudaSafeCall(cudaDeviceSynchronize());
//				else cudaSafeCall( cudaStreamSynchronize(stream));

				cudaSafeCall( cudaMemcpy( h_change, d_change, sizeof(bool), cudaMemcpyDeviceToHost ) );

			}
		}

		cudaSafeCall( cudaFree(d_change) );
		free(h_change);

		printf("Number of iterations: %d\n", iter);
		cudaSafeCall( cudaGetLastError());

	}

	template void imreconstructFloatCaller<float>(DevMem2D_<float> marker, const DevMem2D_<float> mask,
			int connectivity, cudaStream_t stream );
}}
