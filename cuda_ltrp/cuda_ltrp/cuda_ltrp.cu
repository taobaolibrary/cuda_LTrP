//swap_rb.cu
#include <opencv2/core/cuda.hpp>
#include <opencv2/opencv.hpp>
#include <cuda_runtime.h>
#include <device_functions.h>
#include <device_launch_parameters.h>
#include <cuda.h>
#include <iostream>

using namespace std;
using namespace cv;
using namespace cv::cuda;

//extern "C" void lbp_caller(const PtrStepSz<uchar> imageL, const PtrStepSz<uchar> imageR, PtrStepSz<uchar> d_image, int step, int radius, cudaStream_t stream);

extern "C" void ltrp_caller(const PtrStepSz<uchar> imageL, const PtrStepSz<uchar> imageR, PtrStepSz<uchar> resultL, PtrStepSz<uchar> resultR, int choose, cudaStream_t stream);

//自定义内核函数

__device__
bool maxV(float a, float b){
	return a > b;
}

__device__
bool maxAbsV(float a, float b){
	return abs(a) > abs(b);
}

__device__
void selectKMax(float m[], int maxLoc[], int choose, int n){
	float *maxValue = new float[n];
	for (int i = 0; i < n; i++){
		maxLoc[i] = 0;
		maxValue[i] = m[0];
	}

	for (int i = 0; i < 8; i++){
		int j = 0;
		for (; j < n; j++){
			if (choose == 0){
				if (!maxAbsV(m[i], maxValue[j])){
					break;
				}
			}
			else if (choose == 1){
				if (!maxV(m[i], maxValue[j])){
					break;
				}
			}

		}

		//printf("%d\n", j);

		if (j > 0){
			for (int k = j - 1; k > 0; k--){
				maxValue[k - 1] = maxValue[k];
				maxLoc[k - 1] = maxLoc[k];
			}
			maxValue[j - 1] = m[i];
			maxLoc[j - 1] = i;
		}
	}
	delete[]maxValue;
}

__device__
void computeM(uchar a, uchar b, uchar c, float &m){
	m = sqrt((b - a) * (b - a) * 1.0f + (c - a) * (c - a) * 1.0f);
}

__device__
void computeDir(uchar h1, uchar v1, uchar h2, uchar v2, uchar &d){
	char difV = v1 - v2;
	char difH = h1 - h2;
	if (difV >= 0 && difH >= 0){
		d = 0;
	}
	else if (difV >= 0 && difH < 0){
		d = 1;
	}
	else if (difV < 0 && difH < 0){
		d = 2;
	}
	else{
		d = 3;
	}
	//printf("(%d	%d	%d	%d)\n", v1, h1, v2, h2);
	//printf("(%d	%d)\n", difV, difH);
}

//
//void LTrP_(cv::InputArray _src, uchar &code, int i, int j){
//	int x[9] = { 1, 2, 4, 8, 16, 32, 64, 128, 256 };
//	int dir[8][2] = { { -1, 0 }, { -1, -1 }, { 0, -1 }, { 1, -1 }, { 1, 0 }, { 1, 1 }, { 0, 1 }, { -1, 1 } };
//	int dir2[2][2] = { { 0, 1 }, { -1, 0 } };
//	float m[8] = { 0, 0, 0, 0, 0, 0, 0, 0 };
//	uchar codeBit[8] = { 0, 0, 0, 0, 0, 0, 0, 0 };
//	code = 0;
//
//	// get matrices  
//	cv::Mat src = _src.getMat();
//	//_Tp center = src.at<_Tp>(i, j);
//	//cout<<"center"<<(int)center<<"  ";  
//	float gc, gp;
//	computeM(src.ptr<_Tp1>(i)[j], src.ptr<_Tp1>(dir2[0][0] + i)[dir2[0][1] + j], src.ptr<_Tp1>(dir2[1][0] + i)[dir2[1][1] + j], gc);
//
//	for (int d = 0; d < 8; d++){
//		computeM(src.ptr<_Tp1>(dir[d][0] + i)[dir[d][1] + j], src.ptr<_Tp1>(dir2[0][0] + i)[dir2[0][1] + j], src.ptr<_Tp1>(dir2[1][0] + i)[dir2[1][1] + j], gp);
//		if (gp >= gc){
//			code += x[d];
//		}
//	}
//}
//
//
//void CLTrP_(cv::InputArray _src, uchar &code, int i, int j){
//	int x[5] = { 1, 4, 16, 64, 256 };
//	//int dir[8][2] = { { -1, 0 }, { -1, -1 }, { 0, -1 }, { 1, -1 }, { 1, 0 }, { 1, 1 }, { 0, 1 }, { -1, 1 } };
//	int loc[4][2] {{-1, 1}, { 0, 1 }, { 1, 1 }, { 1, 0 }};
//	int dir2[2][2] = { { 0, 1 }, { -1, 0 } };
//	float m[8] = { 0, 0, 0, 0, 0, 0, 0, 0 };
//	uchar codeBit[8] = { 0, 0, 0, 0, 0, 0, 0, 0 };
//	code = 0;
//
//	// get matrices  
//	cv::Mat src = _src.getMat();
//
//	int p1_col, p1_row, p2_col, p2_row;
//	cv::Point2i p1h, p1v, p2h, p2v;
//
//	for (int k = 0; k < 4; k++){
//		uchar d = 0;
//		p1_row = i + loc[k][0];
//		p1_col = j + loc[k][1];
//		p2_row = i - loc[k][0];
//		p2_col = j - loc[k][1];
//
//		p1h.y = p1_row + dir2[0][0];
//		p1h.x = p1_col + dir2[0][1];
//		p1v.y = p1_row + dir2[1][0];
//		p1v.x = p1_col + dir2[1][1];
//
//		p2h.y = p2_row + dir2[0][0];
//		p2h.x = p2_col + dir2[0][1];
//		p2v.y = p2_row + dir2[1][0];
//		p2v.x = p2_col + dir2[1][1];
//
//		//printf("(%d	%d	%d	%d)	(%d	%d	%d	%d)\n", p1h.y, p1h.x, p1v.y, p1v.x, p2h.y, p2h.x, p2v.y, p2v.x);
//
//		computeDir(src.ptr<uchar>(p1h.y)[p1h.x],
//			src.ptr<uchar>(p1v.y)[p1v.x],
//			src.ptr<uchar>(p2h.y)[p2h.x],
//			src.ptr<uchar>(p2v.y)[p2v.x],
//			d);
//		code += d*x[k];
//	}
//}



////////////////////////////////////////////////////////////////////////////////////////////////////////////



__device__
void meanRoiVal(float &meanVal, const PtrStepSz<uchar> image, int2 p, int radius, float num){
	//num = radius*radius。由于num是相同的，所以将其放到外面求，没必要让每个线程求；
	float sum = 0;
#pragma unroll
	for (int r = 0; r < radius; r++){
#pragma unrall
		for (int c = 0; c < radius; c++){
			sum += (uchar)image.ptr(p.y + r)[p.x + c];
		}
	}
	meanVal = sum / num;
}

__device__
void subMean(float &sub, uchar a, uchar b){
	sub = a - b;
	//sub += abs(a.y - b.y);
	//sub += abs(a.z - b.z);
}


__device__
void ltrp_(const PtrStepSz<uchar> _src, uchar &code, int i, int j) {
	int x[9] = { 1, 2, 4, 8, 16, 32, 64, 128, 256 };
	int dir[8][2] = { { -1, 0 }, { -1, -1 }, { 0, -1 }, { 1, -1 }, { 1, 0 }, { 1, 1 }, { 0, 1 }, { -1, 1 } };
	int dir2[2][2] = { { 0, 1 }, { -1, 0 } };
	float m[8] = { 0, 0, 0, 0, 0, 0, 0, 0 };
	uchar codeBit[8] = { 0, 0, 0, 0, 0, 0, 0, 0 };
	code = 0;

	// get matrices  
	//cv::Mat src = _src.getMat();
	//_Tp center = src.at<_Tp>(i, j);
	//cout<<"center"<<(int)center<<"  ";  
	float gc, gp;
	computeM((uchar)_src.ptr(i)[j], (uchar)_src.ptr(dir2[0][0] + i)[dir2[0][1] + j], (uchar)_src.ptr(dir2[1][0] + i)[dir2[1][1] + j], gc);

	for (int d = 0; d < 8; d++){
		computeM((uchar)_src.ptr(dir[d][0] + i)[dir[d][1] + j], (uchar)_src.ptr(dir2[0][0] + i)[dir2[0][1] + j], (uchar)_src.ptr(dir2[1][0] + i)[dir2[1][1] + j], gp);
		if (gp >= gc){
			code += x[d];
		}
	}

}


__device__
void csltrp_(const PtrStepSz<uchar> _src, uchar &code, int i, int j) {
	int x[5] = { 1, 4, 16, 64, 256 };
	//int dir[8][2] = { { -1, 0 }, { -1, -1 }, { 0, -1 }, { 1, -1 }, { 1, 0 }, { 1, 1 }, { 0, 1 }, { -1, 1 } };
	int loc[4][2] {{-1, 1}, { 0, 1 }, { 1, 1 }, { 1, 0 }};
	int dir2[2][2] = { { 0, 1 }, { -1, 0 } };
	float m[8] = { 0, 0, 0, 0, 0, 0, 0, 0 };
	uchar codeBit[8] = { 0, 0, 0, 0, 0, 0, 0, 0 };
	code = 0;

	// get matrices  
	//cv::Mat src = _src.getMat();

	int p1_col, p1_row, p2_col, p2_row;
	int2 p1h, p1v, p2h, p2v;

	for (int k = 0; k < 4; k++){
		uchar d = 0;
		p1_row = i + loc[k][0];
		p1_col = j + loc[k][1];
		p2_row = i - loc[k][0];
		p2_col = j - loc[k][1];

		p1h.y = p1_row + dir2[0][0];
		p1h.x = p1_col + dir2[0][1];
		p1v.y = p1_row + dir2[1][0];
		p1v.x = p1_col + dir2[1][1];

		p2h.y = p2_row + dir2[0][0];
		p2h.x = p2_col + dir2[0][1];
		p2v.y = p2_row + dir2[1][0];
		p2v.x = p2_col + dir2[1][1];

		//printf("(%d	%d	%d	%d)	(%d	%d	%d	%d)\n", p1h.y, p1h.x, p1v.y, p1v.x, p2h.y, p2h.x, p2v.y, p2v.x);

		computeDir((uchar)_src.ptr(p1h.y)[p1h.x],
			(uchar)_src.ptr(p1v.y)[p1v.x],
			(uchar)_src.ptr(p2h.y)[p2h.x],
			(uchar)_src.ptr(p2v.y)[p2v.x],
			d);
		code += d*x[k];
	}
}



//
//__device__
//void lbp(float &znccVal, const PtrStepSz<uchar> imageL, const PtrStepSz<uchar> imageR, int2 pl, int2 pr, int radius, float num){
//	float LmeanVal = .0f;
//	float RmeanVal = .0f;
//	//求将左右视图感兴趣区域的均值
//	meanRoiVal(LmeanVal, imageL, pl, radius, num);
//	meanRoiVal(RmeanVal, imageR, pr, radius, num);
//
//	//求分子
//	//求分母
//	//numerator分子，denominator分母
//	float numerator = .0f;
//	float denominator = .0f;
//	float val1 = .0f;
//	float val2 = .0f;
//#pragma unrall
//	for (int r = 0; r < radius; r++){
//#pragma unrall
//		for (int c = 0; c < radius; c++){
//			float LsubMean = .0f;
//			float RsubMean = .0f;
//			subMean(LsubMean, (uchar)imageL.ptr(pl.y + r)[pl.x + c], LmeanVal);
//			subMean(RsubMean, (uchar)imageR.ptr(pr.y + r)[pr.x + c], RmeanVal);
//			numerator += LsubMean*RsubMean;
//			val1 += LsubMean * LsubMean;
//			val2 += RsubMean * RsubMean;
//		}
//	}
//
//	denominator = sqrt(val1*val2);
//
//	//对分母为0的情况进行处理
//	//否则zncc=分子/分母
//	if (denominator == 0){
//		znccVal = 0;
//	}
//	else{
//		znccVal = numerator / denominator;
//	}
//}
//
//
//__device__
//void cslbp(float &znccVal, const PtrStepSz<uchar> imageL, const PtrStepSz<uchar> imageR, int2 pl, int2 pr, int radius, float num){
//	float LmeanVal = .0f;
//	float RmeanVal = .0f;
//	//求将左右视图感兴趣区域的均值
//	meanRoiVal(LmeanVal, imageL, pl, radius, num);
//	meanRoiVal(RmeanVal, imageR, pr, radius, num);
//
//	//求分子
//	//求分母
//	//numerator分子，denominator分母
//	float numerator = .0f;
//	float denominator = .0f;
//	float val1 = .0f;
//	float val2 = .0f;
//#pragma unrall
//	for (int r = 0; r < radius; r++){
//#pragma unrall
//		for (int c = 0; c < radius; c++){
//			float LsubMean = .0f;
//			float RsubMean = .0f;
//			subMean(LsubMean, (uchar)imageL.ptr(pl.y + r)[pl.x + c], LmeanVal);
//			subMean(RsubMean, (uchar)imageR.ptr(pr.y + r)[pr.x + c], RmeanVal);
//			numerator += LsubMean*RsubMean;
//			val1 += LsubMean * LsubMean;
//			val2 += RsubMean * RsubMean;
//		}
//	}
//
//	denominator = sqrt(val1*val2);
//
//	//对分母为0的情况进行处理
//	//否则zncc=分子/分母
//	if (denominator == 0){
//		znccVal = 0;
//	}
//	else{
//		znccVal = numerator / denominator;
//	}
//}





//__device__
//void subuchar3(float &sub, uchar a, uchar b){
//	sub = a - b;
//	//sub += abs(a.y - b.y);
//	//sub += abs(a.z - b.z);
//}
//
//__device__
//void subquare(float &subSqVal, uchar a, uchar b){
//	subuchar3(subSqVal, a, b);
//	subSqVal *= subSqVal;
//}
//
//__device__
//void subsquareroi(float &sum, const PtrStepSz<uchar> imageL, const PtrStepSz<uchar> imageR, int2 p1, int2 p2, int radius, int W, float pre_subv){
//	sum = 0;
//	float abssub = 0;
//	int r = 0, c = 0;
//#pragma unrall
//	for (r = 0; r < radius; r++){
//#pragma unrall
//		for (c = 0; c < radius; c++){
//			subquare(abssub, (uchar)imageL.ptr(p1.y + r)[p1.x + c], (uchar)imageR.ptr(p2.y + r)[p2.x + c]);
//			sum += abssub;
//			if (sum >= pre_subv){
//				r = radius + 2;
//				c = radius + 2;
//				sum = -1;
//			}
//		}
//	}
//}
//
//__device__
//void adduchar3(float &sum, uchar p){
//	sum += p;
//}
//
//__device__
//void subuchar3abs(float &sub, uchar a, uchar b){
//	sub = abs(a - b);
//	//sub += abs(a.y - b.y);
//	//sub += abs(a.z - b.z);
//}
//
//__device__
//void subabs(float &sum, const PtrStepSz<uchar> imageL, const PtrStepSz<uchar> imageR, int2 p1, int2 p2, int radius, int W){
//	sum = 0;
//#pragma unroll
//	for (int r = 0; r < radius; r++){
//		for (int c = 0; c < radius; c++){
//			float abssub = 0;
//			subuchar3abs(abssub, (uchar)imageL.ptr(p1.y + r)[p1.x + c], (uchar)imageR.ptr(p2.y + r)[p2.x + c]);
//			sum += abssub;
//		}
//	}
//}
//
//__device__
//void subabs2(float &sum, const PtrStepSz<uchar> imageL, const PtrStepSz<uchar> imageR, int2 p1, int2 p2, int radius, int W, float pre_subv){
//	sum = 0;
//	float abssub = 0;
//	int r = 0, c = 0;
//	for (r = 0; r < radius; r++){
//		for (c = 0; c < radius; c++){
//			subuchar3abs(abssub, (uchar)imageL.ptr(p1.y + r)[p1.x + c], (uchar)imageR.ptr(p2.y + r)[p2.x + c]);
//			sum += abssub;
//			if (sum >= pre_subv){
//				r = radius + 2;
//				c = radius + 2;
//				sum = -1;
//			}
//		}
//	}
//}
//
//__global__
//void match_kernel2(int H, int W, const PtrStepSz<uchar> imageL, const PtrStepSz<uchar> imageR, PtrStepSz<uchar> d_image, PtrStepSz<float> d_subv, int s, int t, int radius){
//	const uint x = threadIdx.x + blockIdx.x * blockDim.x;
//	const uint y = threadIdx.y + blockIdx.y * blockDim.y;
//
//	if (x >= s && x <= W - radius && y <= H - radius){
//		float now_sumv = -1;
//		int2 pL = { 0, 0 }, pR = { 0, 0 };
//		pL.x = x;
//		pL.y = y;
//		float pre_num = (float)d_subv.ptr(pL.y)[pL.x];
//		float pre_step = (uchar)d_image.ptr(pL.y)[pL.x];
//#pragma unrall
//		for (int i = s; i < t; i++){
//			pR.x = x - i;
//			pR.y = y;
//			if (pR.x >= 0){
//				//subabs2(now_sumv, imageL, imageR, pL, pR, radius, W, pre_num);
//				subsquareroi(now_sumv, imageL, imageR, pL, pR, radius, W, pre_num);
//				/*if ((float)d_subv.ptr(pL.y)[pL.x] >= now_sumv){
//					(float)d_subv.ptr(pL.y)[pL.x] = now_sumv;
//					(uchar)d_image.ptr(pL.y)[pL.x] = i;
//					}*/
//				if (now_sumv > 0){
//					pre_num = now_sumv;
//					pre_step = i;
//				}
//			}
//		}
//		(float)d_subv.ptr(pL.y)[pL.x] = pre_num;
//		(uchar)d_image.ptr(pL.y)[pL.x] = pre_step;
//	}
//}
//

__global__
void csltrp_kernel(int H, int W, const PtrStepSz<uchar> image, PtrStepSz<uchar> result){
	const uint x = threadIdx.x + blockIdx.x * blockDim.x;
	const uint y = threadIdx.y + blockIdx.y * blockDim.y;
	int radius = 1;
	if (x >= 0 && x <= W - radius && y <= H - radius){
		//float now_sumv = -1;
		int2 pL = { 0, 0 }, pR = { 0, 0 };
		pL.x = x;
		pL.y = y;
		uchar script;
		csltrp_(image, script, pL.y, pL.x);
		(uchar)result.ptr(pL.y)[pL.x] = script;
	}
}

__global__
void ltrp_kernel(int H, int W, const PtrStepSz<uchar> image, PtrStepSz<uchar> result){
	const uint x = threadIdx.x + blockIdx.x * blockDim.x;
	const uint y = threadIdx.y + blockIdx.y * blockDim.y;
	int radius = 1;
	if (x >= 0 && x <= W - radius && y <= H - radius){
		int2 pL = { 0, 0 }, pR = { 0, 0 };
		pL.x = x;
		pL.y = y;
		uchar script;
		ltrp_(image, script, pL.y, pL.x);
		(uchar)result.ptr(pL.y)[pL.x] = script;
	}
}

__global__
void init_dmat(int H, int W, PtrStepSz<float> d_subv, int value){
	int x = threadIdx.x + blockIdx.x * blockDim.x;
	int y = threadIdx.y + blockIdx.y * blockDim.y;
	if (y < H && x < W){
		(float)d_subv.ptr(y)[x] = value;
	}
}

__global__
void mul_dmat(int H, int W, PtrStepSz<uchar> d_image, uchar value){
	uint x = threadIdx.x + blockIdx.x * blockDim.x;
	uint y = threadIdx.y + blockIdx.y * blockDim.y;
	if (y < H && x < W){
		(uchar)d_image.ptr(y)[x] *= value;
	}
}

void ltrp_caller(const PtrStepSz<uchar> imageL, const PtrStepSz<uchar> imageR, PtrStepSz<uchar> resultL, PtrStepSz<uchar> resultR, int choose, cudaStream_t stream)
{
	uint2 sizeI;
	sizeI.y = imageL.rows;
	sizeI.x = imageL.cols;
	const dim3 blockdim(32, 8);
	const dim3 griddim((sizeI.x + blockdim.x - 1) / blockdim.x, (sizeI.y + blockdim.y - 1) / blockdim.y);

	/*const dim3 blockdim1(32, 8);
	const dim3 griddim1((sizeI.x + blockdim1.x - 1) / blockdim1.x, (sizeI.y + blockdim1.y - 1) / blockdim1.y);*/

	// 	const dim3 blockdim2(256, 1);
	// 	const dim3 griddim2((sizeI.x + blockdim2.x - 1) / blockdim2.x, (sizeI.y + blockdim2.y - 1) / blockdim2.y);


	//Mat subvmat;
	//GpuMat d_imat;
	//GpuMat d_subvmat;

	//d_subvmat.create(sizeI.y, sizeI.x, CV_32F);

	//PtrStepSz<float> d_subv;
	//PtrStepSz<uchar> d_image;
	//d_imat.upload(image);
	//d_subvmat.upload(subvmat);
	//d_image = d_imat;
	//d_subv = d_subvmat;
	/*init_dmat << <griddim1, blockdim1 >> >(sizeI.y, sizeI.x, d_subv, 99999);*/
	//init_dmat << <griddim1, blockdim1 >> >(sizeI.y, sizeI.x, d_subv, 0);
	if (choose == 1){
		ltrp_kernel << <griddim, blockdim, 0, stream >> >(sizeI.y, sizeI.x, imageL, resultL);
		cudaThreadSynchronize();
		if (cudaGetLastError() != cudaSuccess) {
			printf("addKernel launch failed: %s\n", cudaGetErrorString(cudaGetLastError()));
		}

		ltrp_kernel << <griddim, blockdim, 0, stream >> >(sizeI.y, sizeI.x, imageR, resultR);
		cudaThreadSynchronize();
		if (cudaGetLastError() != cudaSuccess) {
			printf("addKernel launch failed: %s\n", cudaGetErrorString(cudaGetLastError()));
		}
	}
	else if (choose == 0){
		csltrp_kernel << <griddim, blockdim, 0, stream >> >(sizeI.y, sizeI.x, imageL, resultL);
		cudaThreadSynchronize();
		if (cudaGetLastError() != cudaSuccess) {
			printf("addKernel launch failed: %s\n", cudaGetErrorString(cudaGetLastError()));
		}

		csltrp_kernel << <griddim, blockdim, 0, stream >> >(sizeI.y, sizeI.x, imageR, resultR);
		cudaThreadSynchronize();
		if (cudaGetLastError() != cudaSuccess) {
			printf("addKernel launch failed: %s\n", cudaGetErrorString(cudaGetLastError()));
		}
	}

	//d_imat.download(image);
	/*d_subvmat.download(subvmat);
	for (int i = 0; i < 2; i++){
	for (int j = 0; j < sizeI.x; j++){
	printf("(%d %.0f) ", image.at<uchar>(i, j), subvmat.at<float>(i, j));
	}
	printf("\n\n");
	}*/

	//mul_dmat <<<griddim, blockdim >>>(sizeI.y, sizeI.x, d_image, 16);
	cudaThreadSynchronize();
	//d_imat.download(image);

	//d_subvmat.release();
	if (stream == 0)
		cudaDeviceSynchronize();
}


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
void meanRoiVal2(float &meanVal, Mat image, int2 p1, int2 p2, int radius, float num, int W){
	//num = radius*radius。由于num是相同的，所以将其放到外面求，没必要让每个线程求；
	float sum = 0;
#pragma unroll
	for (int r = 0; r < radius; r++){
		for (int c = 0; c < radius; c++){
			sum += (uchar)image.ptr(p1.y + r)[p1.x + c];
		}
	}
	meanVal = sum / num;
}

void subMean2(float &sub, uchar a, uchar b){
	sub = a - b;
	//sub += abs(a.y - b.y);
	//sub += abs(a.z - b.z);
}

void znccRoi2(float &znccVal, Mat imageL, Mat imageR, int2 p1, int2 p2, int radius, float num, int W){
	float LmeanVal = .0f;
	float RmeanVal = .0f;
	//求将左右视图感兴趣区域的均值
	meanRoiVal2(LmeanVal, imageL, p1, p2, radius, num, W);
	meanRoiVal2(RmeanVal, imageR, p1, p2, radius, num, W);

	float LsubMean = .0f;
	float RsubMean = .0f;
	//求分子
	//求分母
	//numerator分子，denominator分母
	float numerator = .0f;
	float denominator = .0f;
	float val1 = .0f;
	float val2 = .0f;
	for (int r = 0; r < radius; r++){
		for (int c = 0; c < radius; c++){
			subMean2(LsubMean, (uchar)imageL.ptr(p1.y + r)[p1.x + c], LmeanVal);
			subMean2(RsubMean, (uchar)imageR.ptr(p1.y + r)[p1.x + c], RmeanVal);
			numerator += LsubMean*RsubMean;
			val1 += LsubMean * LsubMean;
			val2 += RsubMean * RsubMean;
		}
	}

	denominator = sqrt(val1*val2);

	//对分母为0的情况进行处理
	//否则zncc=分子/分母
	if (denominator == 0){
		znccVal = 0;
	}
	else{
		znccVal = numerator / denominator;
	}
	cout << "LsubMean:	" << LmeanVal << endl;
	cout << "RsubMean:	" << RmeanVal << endl;
	cout << "numerator:	" << numerator << endl;
	cout << "denominator:	" << denominator << endl;
}



extern "C" void testZNCC();

void testZNCC(){
	Mat a = Mat(2, 2, CV_8U, Scalar::all(1));
	Mat b = a.clone();

	a.at<uchar>(0, 1) = 9;
	b.at<uchar>(0, 1) = 59;
	b.at<uchar>(1, 1) = 29;
	b.at<uchar>(1, 0) = 29;
	b.at<uchar>(0, 0) = 29;

	// 	Scalar s = imfunc.zeroMeanNCC(a, b);
	// 
	// 	cout << s << endl;

	//Mat img = Mat(3, 3, CV_8U, Scalar::all(1));
	//img.at<uchar>(0, 1) = 15;

	float now_sumv;
	int2 pL = { 0, 0 }, pR = { 0, 0 };
	znccRoi2(now_sumv, a, b, pL, pR, 2, 4, 2);

	cout << "calZMCC" << endl << now_sumv << endl;

}

