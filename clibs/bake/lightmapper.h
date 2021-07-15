/***********************************************************
* A single header file OpenGL lightmapping library         *
* https://github.com/ands/lightmapper                      *
* no warranty implied | use at your own risk               *
* author: Andreas Mantler (ands) | last change: 10.05.2018 *
*                                                          *
* License:                                                 *
* This software is in the public domain.                   *
* Where that dedication is not recognized,                 *
* you are granted a perpetual, irrevocable license to copy *
* and modify this file however you want.                   *
* From: kitchen.gz.020@gmail.com                           *
* 2021-05-20: add bgfx support                             *
***********************************************************/

#ifndef LIGHTMAPPER_H
#define LIGHTMAPPER_H

#ifdef __cplusplus
#define LM_DEFAULT_VALUE(value) = value
#else
#define LM_DEFAULT_VALUE(value)
#endif

#ifndef LM_CALLOC
#define LM_CALLOC(count, size) calloc(count, size)
#endif

#ifndef LM_FREE
#define LM_FREE(ptr) free(ptr)
#endif

typedef int lm_bool;
#define LM_FALSE 0
#define LM_TRUE  1

typedef int lm_type;
#define LM_NONE           0
#define LM_UNSIGNED_BYTE  1
#define LM_UNSIGNED_SHORT 2
#define LM_UNSIGNED_INT   3
#define LM_FLOAT          4

#define HEMI_FRAMEBUFFER_UNIT_SIZE	512

typedef struct lm_context lm_context;

// creates a lightmapper instance. it can be used to render multiple lightmaps.
lm_context *lmCreate(
	int hemisphereSize,                                                                                // hemisphereSize: resolution of the hemisphere renderings. must be a power of two! typical: 64.
	float zNear, float zFar,                                                                           // zNear/zFar: hemisphere min/max draw distances.
	int interpolationPasses, float interpolationThreshold,                                             // passes: hierarchical selective interpolation passes (0-8; initial step size = 2^passes).
	                                                                                                   // threshold: error value below which lightmap pixels are interpolated instead of rendered.
	                                                                                                   // use output image from LM_DEBUG_INTERPOLATION to determine a good value.
	                                                                                                   // values around and below 0.01 are probably ok.
	                                                                                                   // the lower the value, the more hemispheres are rendered -> slower, but possibly better quality.
	float cameraToSurfaceDistanceModifier LM_DEFAULT_VALUE(0.0f));                                     // modifier for the height of the rendered hemispheres above the surface
	                                                                                                   // -1.0f => stick to surface, 0.0f => minimum height for interpolated surface normals,
	                                                                                                   // > 0.0f => improves gradients on surfaces with interpolated normals due to the flat surface horizon,
	                                                                                                   // but may introduce other artifacts.

// return hemi count in X and Y
void lmFramebufferHemiCount(lm_context *ctx, int *hemix, int *hemiy);

// // optional: set material characteristics by specifying cos(theta)-dependent weights for incoming light.
// typedef float (*lm_weight_func)(float cos_theta, void *userdata);
// void lmSetHemisphereWeights(lm_context *ctx, lm_weight_func f, void *userdata);                        // precalculates weights for incoming light depending on its angle. (default: all weights are 1.0f)

// specify an output lightmap image buffer with w * h * c * sizeof(float) bytes of memory.
void lmSetTargetLightmap(lm_context *ctx, float *outLightmap, uint16_t w, uint16_t h, uint8_t c);                    // output HDR lightmap (linear 32bit float channels; c: 1->Greyscale, 2->Greyscale+Alpha, 3->RGB, 4->RGBA).

// set the geometry to map to the currently set target lightmap (set the target lightmap before calling this!).
void lmSetGeometry(lm_context *ctx,
	const float *transformationMatrix,                                                                 // 4x4 object-to-world transform for the geometry or NULL (no transformation).
	lm_type positionsType, const void *positionsXYZ, int positionsStride,                              // triangle mesh in object space.
	lm_type normalsType, const void *normalsXYZ, int normalsStride,                                    // optional normals for the mesh in object space (Use LM_NONE type in case you only need flat surfaces).
	lm_type lightmapCoordsType, const void *lightmapCoordsUV, int lightmapCoordsStride,                // lightmap atlas texture coordinates for the mesh [0..1]x[0..1] (integer types are normalized to 0..1 range).
	int count, lm_type indicesType LM_DEFAULT_VALUE(LM_NONE), const void *indices LM_DEFAULT_VALUE(0));// if mesh indices are used, count = number of indices else count = number of vertices.

float lmProgress(lm_context *ctx);                                                                     // should only be called between lmBegin/lmEnd!
                                                                                                       // provides the light mapping progress as a value increasing from 0.0 to 1.0.

// destroys the lightmapper instance. should be called to free resources.
void lmDestroy(lm_context *ctx);


// image based post processing (c is the number of color channels in the image, m a channel mask for the operation)
#define LM_ALL_CHANNELS 0x0f
float lmImageMin(const float *image, int w, int h, int c, int m LM_DEFAULT_VALUE(LM_ALL_CHANNELS));                    // find the minimum value (across the specified channels)
float lmImageMax(const float *image, int w, int h, int c, int m LM_DEFAULT_VALUE(LM_ALL_CHANNELS));                    // find the maximum value (across the specified channels)
void lmImageAdd(float *image, int w, int h, int c, float value, int m LM_DEFAULT_VALUE(LM_ALL_CHANNELS));              // in-place add to the specified channels
void lmImageScale(float *image, int w, int h, int c, float factor, int m LM_DEFAULT_VALUE(LM_ALL_CHANNELS));           // in-place scaling of the specified channels
void lmImagePower(float *image, int w, int h, int c, float exponent, int m LM_DEFAULT_VALUE(LM_ALL_CHANNELS));         // in-place powf(v, exponent) of the specified channels (for gamma)
void lmImageDilate(const float *image, float *outImage, int w, int h, int c);                                          // widen the populated non-zero areas by 1 pixel.
void lmImageSmooth(const float *image, float *outImage, int w, int h, int c);                                          // simple box filter on only the non-zero values.
void lmImageDownsample(const float *image, float *outImage, int w, int h, int c);                                      // downsamples [0..w]x[0..h] to [0..w/2]x[0..h/2] by avereging only the non-zero values
void lmImageFtoUB(const float *image, uint8_t *outImage, int w, int h, int c, float max LM_DEFAULT_VALUE(0.0f)); // casts a floating point image to an 8bit/channel image

// TGA file output helpers
lm_bool lmImageSaveTGAub(const char *filename, const uint8_t *image, int w, int h, int c);
lm_bool lmImageSaveTGAf(const char *filename, const float *image, int w, int h, int c, float max LM_DEFAULT_VALUE(0.0f));

#endif
////////////////////// END OF HEADER //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#ifdef LIGHTMAPPER_IMPLEMENTATION
#undef LIGHTMAPPER_IMPLEMENTATION

#include <stdlib.h>
#include <stdio.h>
#include <math.h>
#include <float.h>
#include <assert.h>
#include <limits.h>


#define LM_SWAP(type, a, b) { type tmp = (a); (a) = (b); (b) = tmp; }

#if defined(_MSC_VER) && !defined(__cplusplus)
#define inline __inline
#endif

#if defined(_MSC_VER) && (_MSC_VER <= 1700)
static inline lm_bool lm_finite(float a) { return _finite(a); }
#else
static inline lm_bool lm_finite(float a) { return isfinite(a); }
#endif

static inline int      lm_mini      (int     a, int     b) { return a < b ? a : b; }
static inline int      lm_maxi      (int     a, int     b) { return a > b ? a : b; }
static inline int      lm_absi      (int     a           ) { return a < 0 ? -a : a; }
static inline float    lm_minf      (float   a, float   b) { return a < b ? a : b; }
static inline float    lm_maxf      (float   a, float   b) { return a > b ? a : b; }
static inline float    lm_absf      (float   a           ) { return a < 0.0f ? -a : a; }
static inline float    lm_pmodf     (float   a, float   b) { return (a < 0.0f ? 1.0f : 0.0f) + (float)fmod(a, b); } // positive mod

typedef struct lm_ivec2 { int x, y; } 	lm_ivec2;
static inline lm_ivec2 lm_i2        (int     x, int     y) { lm_ivec2 v = { x, y }; return v; }
typedef struct lm_uivec2{uint32_t x, y;}lm_uivec2;
static inline lm_uivec2 lm_ui2(uint32_t x, uint32_t y) { lm_uivec2 v = {x, y}; return v; }

typedef struct lm_vec2 { float x, y; } lm_vec2;
static inline lm_vec2  lm_v2i       (int     x, int     y) { lm_vec2 v = { (float)x, (float)y }; return v; }
static inline lm_vec2  lm_v2        (float   x, float   y) { lm_vec2 v = { x, y }; return v; }
static inline lm_vec2  lm_negate2   (lm_vec2 a           ) { return lm_v2(-a.x, -a.y); }
static inline lm_vec2  lm_add2      (lm_vec2 a, lm_vec2 b) { return lm_v2(a.x + b.x, a.y + b.y); }
static inline lm_vec2  lm_sub2      (lm_vec2 a, lm_vec2 b) { return lm_v2(a.x - b.x, a.y - b.y); }
static inline lm_vec2  lm_mul2      (lm_vec2 a, lm_vec2 b) { return lm_v2(a.x * b.x, a.y * b.y); }
static inline lm_vec2  lm_scale2    (lm_vec2 a, float   b) { return lm_v2(a.x * b, a.y * b); }
static inline lm_vec2  lm_div2      (lm_vec2 a, float   b) { return lm_scale2(a, 1.0f / b); }
static inline lm_vec2  lm_pmod2     (lm_vec2 a, float   b) { return lm_v2(lm_pmodf(a.x, b), lm_pmodf(a.y, b)); }
static inline lm_vec2  lm_min2      (lm_vec2 a, lm_vec2 b) { return lm_v2(lm_minf(a.x, b.x), lm_minf(a.y, b.y)); }
static inline lm_vec2  lm_max2      (lm_vec2 a, lm_vec2 b) { return lm_v2(lm_maxf(a.x, b.x), lm_maxf(a.y, b.y)); }
static inline lm_vec2  lm_abs2      (lm_vec2 a           ) { return lm_v2(lm_absf(a.x), lm_absf(a.y)); }
static inline lm_vec2  lm_floor2    (lm_vec2 a           ) { return lm_v2(floorf(a.x), floorf(a.y)); }
static inline lm_vec2  lm_ceil2     (lm_vec2 a           ) { return lm_v2(ceilf (a.x), ceilf (a.y)); }
static inline float    lm_dot2      (lm_vec2 a, lm_vec2 b) { return a.x * b.x + a.y * b.y; }
static inline float    lm_cross2    (lm_vec2 a, lm_vec2 b) { return a.x * b.y - a.y * b.x; } // pseudo cross product
static inline float    lm_length2sq (lm_vec2 a           ) { return a.x * a.x + a.y * a.y; }
static inline float    lm_length2   (lm_vec2 a           ) { return sqrtf(lm_length2sq(a)); }
static inline lm_vec2  lm_normalize2(lm_vec2 a           ) { return lm_div2(a, lm_length2(a)); }
static inline lm_bool  lm_finite2   (lm_vec2 a           ) { return lm_finite(a.x) && lm_finite(a.y); }

typedef struct lm_vec3 { float x, y, z; } lm_vec3;
static inline lm_vec3  lm_v3        (float   x, float   y, float   z) { lm_vec3 v = { x, y, z }; return v; }
static inline lm_vec3  lm_negate3   (lm_vec3 a           ) { return lm_v3(-a.x, -a.y, -a.z); }
static inline lm_vec3  lm_add3      (lm_vec3 a, lm_vec3 b) { return lm_v3(a.x + b.x, a.y + b.y, a.z + b.z); }
static inline lm_vec3  lm_sub3      (lm_vec3 a, lm_vec3 b) { return lm_v3(a.x - b.x, a.y - b.y, a.z - b.z); }
static inline lm_vec3  lm_mul3      (lm_vec3 a, lm_vec3 b) { return lm_v3(a.x * b.x, a.y * b.y, a.z * b.z); }
static inline lm_vec3  lm_scale3    (lm_vec3 a, float   b) { return lm_v3(a.x * b, a.y * b, a.z * b); }
static inline lm_vec3  lm_div3      (lm_vec3 a, float   b) { return lm_scale3(a, 1.0f / b); }
static inline lm_vec3  lm_pmod3     (lm_vec3 a, float   b) { return lm_v3(lm_pmodf(a.x, b), lm_pmodf(a.y, b), lm_pmodf(a.z, b)); }
static inline lm_vec3  lm_min3      (lm_vec3 a, lm_vec3 b) { return lm_v3(lm_minf(a.x, b.x), lm_minf(a.y, b.y), lm_minf(a.z, b.z)); }
static inline lm_vec3  lm_max3      (lm_vec3 a, lm_vec3 b) { return lm_v3(lm_maxf(a.x, b.x), lm_maxf(a.y, b.y), lm_maxf(a.z, b.z)); }
static inline lm_vec3  lm_abs3      (lm_vec3 a           ) { return lm_v3(lm_absf(a.x), lm_absf(a.y), lm_absf(a.z)); }
static inline lm_vec3  lm_floor3    (lm_vec3 a           ) { return lm_v3(floorf(a.x), floorf(a.y), floorf(a.z)); }
static inline lm_vec3  lm_ceil3     (lm_vec3 a           ) { return lm_v3(ceilf (a.x), ceilf (a.y), ceilf (a.z)); }
static inline float    lm_dot3      (lm_vec3 a, lm_vec3 b) { return a.x * b.x + a.y * b.y + a.z * b.z; }
static inline lm_vec3  lm_cross3    (lm_vec3 a, lm_vec3 b) { return lm_v3(a.y * b.z - b.y * a.z, a.z * b.x - b.z * a.x, a.x * b.y - b.x * a.y); }
static inline float    lm_length3sq (lm_vec3 a           ) { return a.x * a.x + a.y * a.y + a.z * a.z; }
static inline float    lm_length3   (lm_vec3 a           ) { return sqrtf(lm_length3sq(a)); }
static inline lm_vec3  lm_normalize3(lm_vec3 a           ) { return lm_div3(a, lm_length3(a)); }
static inline lm_bool  lm_finite3   (lm_vec3 a           ) { return lm_finite(a.x) && lm_finite(a.y) && lm_finite(a.z); }

static lm_vec2 lm_toBarycentric(lm_vec2 p1, lm_vec2 p2, lm_vec2 p3, lm_vec2 p)
{
	// http://www.blackpawn.com/texts/pointinpoly/
	// Compute vectors
	lm_vec2 v0 = lm_sub2(p3, p1);
	lm_vec2 v1 = lm_sub2(p2, p1);
	lm_vec2 v2 = lm_sub2(p, p1);
	// Compute dot products
	float dot00 = lm_dot2(v0, v0);
	float dot01 = lm_dot2(v0, v1);
	float dot02 = lm_dot2(v0, v2);
	float dot11 = lm_dot2(v1, v1);
	float dot12 = lm_dot2(v1, v2);
	// Compute barycentric coordinates
	float invDenom = 1.0f / (dot00 * dot11 - dot01 * dot01);
	float u = (dot11 * dot02 - dot01 * dot12) * invDenom;
	float v = (dot00 * dot12 - dot01 * dot02) * invDenom;
	return lm_v2(u, v);
}

static inline int lm_leftOf(lm_vec2 a, lm_vec2 b, lm_vec2 c)
{
	float x = lm_cross2(lm_sub2(b, a), lm_sub2(c, b));
	return x < 0 ? -1 : x > 0;
}

static lm_bool lm_lineIntersection(lm_vec2 x0, lm_vec2 x1, lm_vec2 y0, lm_vec2 y1, lm_vec2* res)
{
	lm_vec2 dx = lm_sub2(x1, x0);
	lm_vec2 dy = lm_sub2(y1, y0);
	lm_vec2 d = lm_sub2(x0, y0);
	float dyx = lm_cross2(dy, dx);
	if (dyx == 0.0f)
		return LM_FALSE;
	dyx = lm_cross2(d, dx) / dyx;
	if (dyx <= 0 || dyx >= 1)
		return LM_FALSE;
	res->x = y0.x + dyx * dy.x;
	res->y = y0.y + dyx * dy.y;
	return LM_TRUE;
}

// this modifies the poly array! the poly array must be big enough to hold the result!
// res must be big enough to hold the result!
static int lm_convexClip(lm_vec2 *poly, int nPoly, const lm_vec2 *clip, int nClip, lm_vec2 *res)
{
	int nRes = nPoly;
	int dir = lm_leftOf(clip[0], clip[1], clip[2]);
	for (int i = 0, j = nClip - 1; i < nClip && nRes; j = i++)
	{
		if (i != 0)
			for (nPoly = 0; nPoly < nRes; nPoly++)
				poly[nPoly] = res[nPoly];
		nRes = 0;
		lm_vec2 v0 = poly[nPoly - 1];
		int side0 = lm_leftOf(clip[j], clip[i], v0);
		if (side0 != -dir)
			res[nRes++] = v0;
		for (int k = 0; k < nPoly; k++)
		{
			lm_vec2 v1 = poly[k], x;
			int side1 = lm_leftOf(clip[j], clip[i], v1);
			if (side0 + side1 == 0 && side0 && lm_lineIntersection(clip[j], clip[i], v0, v1, &x))
				res[nRes++] = x;
			if (k == nPoly - 1)
				break;
			if (side1 != -dir)
				res[nRes++] = v1;
			v0 = v1;
			side0 = side1;
		}
	}

	return nRes;
}

typedef void (*initbuffer_callback)(lm_context*);
typedef void (*render_callback)(lm_context*, int*, float*, float *);
typedef void (*downsample_callback)(lm_context*);
typedef float* (*readlightmap_callback)(lm_context*, int size);
typedef void (*process_callback)(lm_context*);

struct lm_context
{
	struct
	{
		const float *modelMatrix;
		float normalMatrix[9];

		const uint8_t *positions;
		lm_type positionsType;
		uint32_t positionsStride;
		const uint8_t *normals;
		lm_type normalsType;
		uint32_t normalsStride;
		const uint8_t *uvs;
		lm_type uvsType;
		uint32_t uvsStride;
		const uint8_t *indices;
		lm_type indicesType;
		uint32_t count;
	} mesh;

	struct
	{
		uint16_t pass;
		uint16_t passCount;

		struct
		{
			uint32_t baseIndex;
			lm_vec3 p[3];
			lm_vec3 n[3];
			lm_vec2 uv[3];
		} triangle;

		struct
		{
			uint16_t minx, miny;
			uint16_t maxx, maxy;
			uint16_t x, y;
		} rasterizer;

		struct
		{
			lm_vec3 position;
			lm_vec3 direction;
			lm_vec3 up;
		} sample;

		struct
		{
			uint8_t side;
		} hemisphere;
	} meshPosition;

	struct
	{
		float *data;
		uint16_t width;
		uint16_t height;
		uint8_t channels;
#ifdef LM_DEBUG_INTERPOLATION
		uint8_t *debug;
#endif
	} lightmap;

	struct
	{
		float zNear, zFar;
		float cameraToSurfaceDistanceModifier;

		uint16_t size;
		uint16_t fbHemiCountX;
		uint16_t fbHemiCountY;
		uint32_t fbHemiIndex;
		lm_ivec2 *fbHemiToLightmapLocation;

		struct
		{
			//bgfx_texture_handle_t texture;
			lm_uivec2 writePosition;
			lm_ivec2 *toLightmapLocation;
			uint16_t width;
			uint16_t height;
		} storage;

		
	} hemisphere;

	struct {
		initbuffer_callback		init_buffer;
		render_callback			render_scene;
		downsample_callback		downsample;
		readlightmap_callback 	read_lightmap;
		process_callback		process;
		void* userdata;
	} render;

	float interpolationThreshold;
};

// pass order of one 4x4 interpolation patch for two interpolation steps (and the next neighbors right of/below it)
// 0 4 1 4 0
// 5 6 5 6 5
// 2 4 3 4 2
// 5 6 5 6 5
// 0 4 1 4 0

static uint32_t lm_passStepSize(lm_context *ctx)
{
	uint32_t shift = ctx->meshPosition.passCount / 3 - (ctx->meshPosition.pass - 1) / 3;
	uint32_t step = (1 << shift);
	assert(step > 0);
	return step;
}

static uint32_t lm_passOffsetX(lm_context *ctx)
{
	if (!ctx->meshPosition.pass)
		return 0;
	int passType = (ctx->meshPosition.pass - 1) % 3;
	uint32_t halfStep = lm_passStepSize(ctx) >> 1;
	return passType != 1 ? halfStep : 0;
}

static uint32_t lm_passOffsetY(lm_context *ctx)
{
	if (!ctx->meshPosition.pass)
		return 0;
	int passType = (ctx->meshPosition.pass - 1) % 3;
	uint32_t halfStep = lm_passStepSize(ctx) >> 1;
	return passType != 0 ? halfStep : 0;
}

static lm_bool lm_hasConservativeTriangleRasterizerFinished(lm_context *ctx)
{
	return ctx->meshPosition.rasterizer.y >= ctx->meshPosition.rasterizer.maxy;
}

static void lm_moveToNextPotentialConservativeTriangleRasterizerPosition(lm_context *ctx)
{
	uint32_t step = lm_passStepSize(ctx);
	ctx->meshPosition.rasterizer.x += step;
	while (ctx->meshPosition.rasterizer.x >= ctx->meshPosition.rasterizer.maxx)
	{
		ctx->meshPosition.rasterizer.x = ctx->meshPosition.rasterizer.minx + lm_passOffsetX(ctx);
		ctx->meshPosition.rasterizer.y += step;
		if (lm_hasConservativeTriangleRasterizerFinished(ctx))
			break;
	}
}

static float *lm_getLightmapPixel(lm_context *ctx, uint32_t x, uint32_t y)
{
	assert(0 <= x && x < ctx->lightmap.width && 0 <= y && y < ctx->lightmap.height);
	return ctx->lightmap.data + (y * ctx->lightmap.width + x) * ctx->lightmap.channels;
}

static void lm_setLightmapPixel(lm_context *ctx, int x, int y, float *in)
{
	assert(0 <= x && x < ctx->lightmap.width && 0 <= y && y < ctx->lightmap.height);
	float *p = ctx->lightmap.data + (y * ctx->lightmap.width + x) * ctx->lightmap.channels;
	for (uint8_t j = 0; j < ctx->lightmap.channels; ++j)
		*p++ = *in++;
}

#define lm_baseAngle 0.1f
static const float lm_baseAngles[3][3] = {
	{ lm_baseAngle, lm_baseAngle + 1.0f / 3.0f, lm_baseAngle + 2.0f / 3.0f },
	{ lm_baseAngle + 1.0f / 3.0f, lm_baseAngle + 2.0f / 3.0f, lm_baseAngle },
	{ lm_baseAngle + 2.0f / 3.0f, lm_baseAngle, lm_baseAngle + 1.0f / 3.0f }
};

static lm_bool lm_trySamplingConservativeTriangleRasterizerPosition(lm_context *ctx)
{
	// check if lightmap pixel was already set
	float *pixelValue = lm_getLightmapPixel(ctx, ctx->meshPosition.rasterizer.x, ctx->meshPosition.rasterizer.y);
	for (int j = 0; j < ctx->lightmap.channels; j++)
		if (pixelValue[j] != 0.0f)
			return LM_FALSE;

	// try calculating centroid by clipping the pixel against the triangle
	lm_vec2 pixel[16];
	pixel[0] = lm_v2i(ctx->meshPosition.rasterizer.x, ctx->meshPosition.rasterizer.y);
	pixel[1] = lm_v2i(ctx->meshPosition.rasterizer.x + 1, ctx->meshPosition.rasterizer.y);
	pixel[2] = lm_v2i(ctx->meshPosition.rasterizer.x + 1, ctx->meshPosition.rasterizer.y + 1);
	pixel[3] = lm_v2i(ctx->meshPosition.rasterizer.x, ctx->meshPosition.rasterizer.y + 1);

	lm_vec2 res[16];
	int nRes = lm_convexClip(pixel, 4, ctx->meshPosition.triangle.uv, 3, res);
	if (nRes == 0)
		return LM_FALSE; // nothing left

	// calculate centroid position and area
	lm_vec2 centroid = res[0];
	float area = res[nRes - 1].x * res[0].y - res[nRes - 1].y * res[0].x;
	for (int i = 1; i < nRes; i++)
	{
		centroid = lm_add2(centroid, res[i]);
		area += res[i - 1].x * res[i].y - res[i - 1].y * res[i].x;
	}
	centroid = lm_div2(centroid, (float)nRes);
	area = lm_absf(area / 2.0f);

	if (area <= 0.0f)
		return LM_FALSE; // no area left

	// calculate barycentric coords
	lm_vec2 uv = lm_toBarycentric(
		ctx->meshPosition.triangle.uv[0],
		ctx->meshPosition.triangle.uv[1],
		ctx->meshPosition.triangle.uv[2],
		centroid);

	if (!lm_finite2(uv))
		return LM_FALSE; // degenerate

	// try to interpolate color from neighbors:
	if (ctx->meshPosition.pass > 0)
	{
		float *neighbors[4];
		int neighborCount = 0;
		int neighborsExpected = 0;
		int d = (int)lm_passStepSize(ctx) / 2;
		int dirs = ((ctx->meshPosition.pass - 1) % 3) + 1;
		if (dirs & 1) // check x-neighbors with distance d
		{
			neighborsExpected += 2;
			if (ctx->meshPosition.rasterizer.x - d >= ctx->meshPosition.rasterizer.minx &&
				ctx->meshPosition.rasterizer.x + d <= ctx->meshPosition.rasterizer.maxx)
			{
				neighbors[neighborCount++] = lm_getLightmapPixel(ctx, ctx->meshPosition.rasterizer.x - d, ctx->meshPosition.rasterizer.y);
				neighbors[neighborCount++] = lm_getLightmapPixel(ctx, ctx->meshPosition.rasterizer.x + d, ctx->meshPosition.rasterizer.y);
			}
		}
		if (dirs & 2) // check y-neighbors with distance d
		{
			neighborsExpected += 2;
			if (ctx->meshPosition.rasterizer.y - d >= ctx->meshPosition.rasterizer.miny &&
				ctx->meshPosition.rasterizer.y + d <= ctx->meshPosition.rasterizer.maxy)
			{
				neighbors[neighborCount++] = lm_getLightmapPixel(ctx, ctx->meshPosition.rasterizer.x, ctx->meshPosition.rasterizer.y - d);
				neighbors[neighborCount++] = lm_getLightmapPixel(ctx, ctx->meshPosition.rasterizer.x, ctx->meshPosition.rasterizer.y + d);
			}
		}
		if (neighborCount == neighborsExpected) // are all interpolation neighbors available?
		{
			// calculate average neighbor pixel value
			float avg[4] = { 0 };
			for (int i = 0; i < neighborCount; i++)
				for (int j = 0; j < ctx->lightmap.channels; j++)
					avg[j] += neighbors[i][j];
			float ni = 1.0f / neighborCount;
			for (int j = 0; j < ctx->lightmap.channels; j++)
				avg[j] *= ni;

			// check if error from average pixel to neighbors is above the interpolation threshold
			lm_bool interpolate = LM_TRUE;
			for (int i = 0; i < neighborCount; i++)
			{
				lm_bool zero = LM_TRUE;
				for (int j = 0; j < ctx->lightmap.channels; j++)
				{
					if (neighbors[i][j] != 0.0f)
						zero = LM_FALSE;
					if (fabs(neighbors[i][j] - avg[j]) > ctx->interpolationThreshold)
						interpolate = LM_FALSE;
				}
				if (zero)
					interpolate = LM_FALSE;
				if (!interpolate)
					break;
			}

			// set interpolated value and return if interpolation is acceptable
			if (interpolate)
			{
				lm_setLightmapPixel(ctx, ctx->meshPosition.rasterizer.x, ctx->meshPosition.rasterizer.y, avg);
#ifdef LM_DEBUG_INTERPOLATION
				// set interpolated pixel to green in debug output
				ctx->lightmap.debug[(ctx->meshPosition.rasterizer.y * ctx->lightmap.width + ctx->meshPosition.rasterizer.x) * 3 + 1] = 255;
#endif
				return LM_FALSE;
			}
		}
	}

	// could not interpolate. must render a hemisphere.
	// calculate 3D sample position and orientation
	lm_vec3 p0 = ctx->meshPosition.triangle.p[0];
	lm_vec3 p1 = ctx->meshPosition.triangle.p[1];
	lm_vec3 p2 = ctx->meshPosition.triangle.p[2];
	lm_vec3 v1 = lm_sub3(p1, p0);
	lm_vec3 v2 = lm_sub3(p2, p0);
	ctx->meshPosition.sample.position = lm_add3(p0, lm_add3(lm_scale3(v2, uv.x), lm_scale3(v1, uv.y)));

	lm_vec3 n0 = ctx->meshPosition.triangle.n[0];
	lm_vec3 n1 = ctx->meshPosition.triangle.n[1];
	lm_vec3 n2 = ctx->meshPosition.triangle.n[2];
	lm_vec3 nv1 = lm_sub3(n1, n0);
	lm_vec3 nv2 = lm_sub3(n2, n0);
	ctx->meshPosition.sample.direction = lm_normalize3(lm_add3(n0, lm_add3(lm_scale3(nv2, uv.x), lm_scale3(nv1, uv.y))));
	float cameraToSurfaceDistance = (1.0f + ctx->hemisphere.cameraToSurfaceDistanceModifier) * ctx->hemisphere.zNear * sqrtf(2.0f);
	ctx->meshPosition.sample.position = lm_add3(ctx->meshPosition.sample.position, lm_scale3(ctx->meshPosition.sample.direction, cameraToSurfaceDistance));

	if (!lm_finite3(ctx->meshPosition.sample.position) ||
		!lm_finite3(ctx->meshPosition.sample.direction) ||
		lm_length3sq(ctx->meshPosition.sample.direction) < 0.5f) // don't allow 0.0f. should always be ~1.0f
		return LM_FALSE;

	lm_vec3 up = lm_v3(0.0f, 1.0f, 0.0f);
	if (lm_absf(lm_dot3(up, ctx->meshPosition.sample.direction)) > 0.8f)
		up = lm_v3(0.0f, 0.0f, -1.0f);

#if 1
	// triangle-consistent up vector
	//ctx->meshPosition.sample.up = lm_normalize3(lm_cross3(up, ctx->meshPosition.sample.direction));
	lm_vec3 side = lm_normalize3(lm_cross3(up, ctx->meshPosition.sample.direction));
	ctx->meshPosition.sample.up = lm_normalize3(lm_cross3(ctx->meshPosition.sample.direction, side));
	return LM_TRUE;
#else
	// "randomized" rotation with pattern
	lm_vec3 side = lm_normalize3(lm_cross3(up, ctx->meshPosition.sample.direction));
	up = lm_normalize3(lm_cross3(ctx->meshPosition.sample.direction, side));
	int rx = ctx->meshPosition.rasterizer.x % 3;
	int ry = ctx->meshPosition.rasterizer.y % 3;
	static const float lm_pi = 3.14159265358979f;
	float phi = 2.0f * lm_pi * lm_baseAngles[ry][rx];// + 0.1f * ((float)rand() / (float)RAND_MAX);
	ctx->meshPosition.sample.up = lm_normalize3(lm_add3(lm_scale3(side, cosf(phi)), lm_scale3(up, sinf(phi))));
	return LM_TRUE;
#endif
}

//#ifdef _DEBUG
// static uint8_t* get_image_memory(bgfx_texture_handle_t tex, int w, int h, int elemsize)
// {
// 	uint8_t *tt = (uint8_t*)LM_CALLOC(w * h, elemsize);
// 	uint32_t whichframe = BGFX(read_texture)(tex, tt, 0);
// 	while (BGFX(frame)(false) < whichframe);
// 	return tt;
// }

// static bgfx_texture_handle_t create_tex(int w, int h, bgfx_texture_format fmt = BGFX_TEXTURE_FORMAT_RGBA32F){
// 	return BGFX(create_texture_2d)(w, h, false, 1, fmt, 
// 	BGFX_SAMPLER_U_CLAMP|BGFX_SAMPLER_V_CLAMP|BGFX_SAMPLER_MIN_POINT|BGFX_SAMPLER_MAG_POINT|BGFX_TEXTURE_BLIT_DST|BGFX_TEXTURE_READ_BACK
// 	,NULL);
// };

// static void copy_tex(uint16_t viewid, bgfx_texture_handle_t dsttex, bgfx_texture_handle_t srctex, int w, int h){
// 	BGFX(blit)(viewid, dsttex, 
// 	0, //dst mip
// 	0, 0, 0, // dst x, y, z
// 	srctex,
// 	0, //src mip
// 	0, 0, 0, w, h, 0);
// };

// static void save_bin(const char* filename, const float *mm, int w, int h, int numelem)
// {
// 	char* b = (char*)LM_CALLOC(w*h, 32);
// 	char* p = b;
// 	for (int jj=0; jj<h; ++jj){
// 		for (int ii=0; ii<w; ++ii){
// 			int idx = jj*w*numelem+ii;
// 			for (int e=0; e<numelem; ++e){
// 				p += sprintf(p, "%2f ", mm[idx+e]);
// 			}
// 		}

// 		p += sprintf(p, "\n");
// 	}

// 	FILE *f = fopen(filename, "w");
// 	fwrite(b, 1, p-b, f);
// 	fclose(f);

// 	LM_FREE(b);
// }
//#endif //_DEBUG

static lm_bool lm_isStorageFull(lm_context *ctx)
{
	return ctx->hemisphere.storage.writePosition.y + ctx->hemisphere.fbHemiCountY > ctx->hemisphere.storage.height;
}

static lm_bool lm_updateStoragePosition(lm_context *ctx)
{
	assert(!lm_isStorageFull(ctx));
	assert(ctx->hemisphere.fbHemiIndex > 0);
	// copy position mapping to storage
	for (uint32_t y = 0; y < ctx->hemisphere.fbHemiCountY; y++)
	{
		int sy = ctx->hemisphere.storage.writePosition.y + y;
		for (uint32_t x = 0; x < ctx->hemisphere.fbHemiCountX; x++)
		{
			int sx = ctx->hemisphere.storage.writePosition.x + x;
			uint32_t hemiIndex = y * ctx->hemisphere.fbHemiCountX + x;
			ctx->hemisphere.storage.toLightmapLocation[sy * ctx->hemisphere.storage.width + sx] = 
				(hemiIndex >= ctx->hemisphere.fbHemiIndex) ?
				lm_i2(-1, -1) :
				ctx->hemisphere.fbHemiToLightmapLocation[hemiIndex];
		}
	}

	// advance storage texture write position
	ctx->hemisphere.storage.writePosition.x += ctx->hemisphere.fbHemiCountX;
	if (ctx->hemisphere.storage.writePosition.x + ctx->hemisphere.fbHemiCountX > ctx->hemisphere.storage.width)
	{
		ctx->hemisphere.storage.writePosition.x = 0;
		ctx->hemisphere.storage.writePosition.y += ctx->hemisphere.fbHemiCountY;
	}

	ctx->hemisphere.fbHemiIndex = 0;
	return lm_isStorageFull(ctx);
}

static void lm_writeResultsToLightmap(lm_context *ctx)
{
	assert(lm_isStorageFull(ctx));
	// do the GPU->CPU transfer of downsampled hemispheres
	const float *hemi = ctx->render.read_lightmap(ctx, ctx->hemisphere.storage.width * ctx->hemisphere.storage.height * 4 * sizeof(float));

	// write results to lightmap texture
	for (uint32_t y = 0; y < ctx->hemisphere.storage.writePosition.y; ++y)
	{
		for (uint32_t x = 0; x < ctx->hemisphere.storage.width; ++x)
		{
			uint32_t lmlocation = y * ctx->hemisphere.storage.width + x;
			lm_ivec2 lmUV = ctx->hemisphere.storage.toLightmapLocation[lmlocation];
			if (lmUV.x >= 0)
			{
				const float *c = hemi + (y * ctx->hemisphere.storage.width + x) * 4;
				float validity = c[3];
				float *lm = ctx->lightmap.data + (lmUV.y * ctx->lightmap.width + lmUV.x) * ctx->lightmap.channels;
				if (!lm[0] && validity > 0.9)
				{
					float scale = 1.0f / validity;
					switch (ctx->lightmap.channels)
					{
					case 1:
						lm[0] = lm_maxf((c[0] + c[1] + c[2]) * scale / 3.0f, FLT_MIN);
						break;
					case 2:
						lm[0] = lm_maxf((c[0] + c[1] + c[2]) * scale / 3.0f, FLT_MIN);
						lm[1] = 1.0f; // do we want to support this format?
						break;
					case 3:
						lm[0] = lm_maxf(c[0] * scale, FLT_MIN);
						lm[1] = lm_maxf(c[1] * scale, FLT_MIN);
						lm[2] = lm_maxf(c[2] * scale, FLT_MIN);
						break;
					case 4:
						lm[0] = lm_maxf(c[0] * scale, FLT_MIN);
						lm[1] = lm_maxf(c[1] * scale, FLT_MIN);
						lm[2] = lm_maxf(c[2] * scale, FLT_MIN);
						lm[3] = 1.0f;
						break;
					default:
						assert(LM_FALSE);
						break;
					}

#ifdef LM_DEBUG_INTERPOLATION
					// set sampled pixel to red in debug output
					ctx->lightmap.debug[(lmUV.y * ctx->lightmap.width + lmUV.x) * 3 + 0] = 255;
#endif
				}
			}
			ctx->hemisphere.storage.toLightmapLocation[lmlocation].x = -1; // reset
		}
	}

	ctx->hemisphere.storage.writePosition = lm_ui2(0, 0);
}

static void lm_integrateHemisphereBatch(lm_context *ctx)
{
	ctx->render.downsample(ctx);
	lm_updateStoragePosition(ctx);
	if (lm_isStorageFull(ctx))
		lm_writeResultsToLightmap(ctx); // read storage data from gpu memory and write it to the lightmap
}

static void lm_setView(
	int* viewport, int x, int y, int w, int h,
	float* view,   lm_vec3 pos, lm_vec3 dir, lm_vec3 up,
	float* proj,   float l, float r, float b, float t, float n, float f)
{
	// viewport
	viewport[0] = x; viewport[1] = y; viewport[2] = w; viewport[3] = h;

	// view matrix: lookAt(pos, pos + dir, up), left hand
	// lm_vec3 side = lm_cross3(dir, up);
	// //up = cross(side, dir);
	// dir = lm_negate3(dir); pos = lm_negate3(pos);
	// view[ 0] = side.x;             view[ 1] = up.x;             view[ 2] = dir.x;             view[ 3] = 0.0f;
	// view[ 4] = side.y;             view[ 5] = up.y;             view[ 6] = dir.y;             view[ 7] = 0.0f;
	// view[ 8] = side.z;             view[ 9] = up.z;             view[10] = dir.z;             view[11] = 0.0f;
	// view[12] = lm_dot3(side, pos); view[13] = lm_dot3(up, pos); view[14] = lm_dot3(dir, pos); view[15] = 1.0f;

	lm_vec3 side = lm_cross3(up, dir);

	view[ 0] = side.x; 				view[ 1] = up.x; 				view[ 2] = dir.x; 				view[ 3] = 0.f;
	view[ 4] = side.y; 				view[ 5] = up.y; 				view[ 6] = dir.y; 				view[ 7] = 0.f;
	view[ 8] = side.z; 				view[ 9] = up.z; 				view[10] = dir.z; 				view[11] = 0.f;
	view[12] = -lm_dot3(side, pos); view[13] = -lm_dot3(up, pos);	view[14] = -lm_dot3(dir, pos); 	view[15] = 1.f;

	// projection matrix: frustum(l, r, b, t, n, f), depth: [0, 1]
	// float ilr = 1.0f / (r - l), ibt = 1.0f / (t - b), ninf = -1.0f / (f - n), n2 = 2.0f * n;
	// proj[ 0] = n2 * ilr;      proj[ 1] = 0.0f;          proj[ 2] = 0.0f;           proj[ 3] = 0.0f;
	// proj[ 4] = 0.0f;          proj[ 5] = n2 * ibt;      proj[ 6] = 0.0f;           proj[ 7] = 0.0f;
	// proj[ 8] = (r + l) * ilr; proj[ 9] = (t + b) * ibt; proj[10] = (f + n) * ninf; proj[11] = -1.0f;
	// proj[12] = 0.0f;          proj[13] = 0.0f;          proj[14] = f * n2 * ninf;  proj[15] = 0.0f;

	proj[0] = 2.f*n/(r-l);	proj[1] = 0.f; 			proj[2]	= 0.f; 				proj[3] = 0.f;
	proj[4] = 0.f;			proj[5] = (2.f*n)/(t-b);proj[6] = 0.f; 				proj[7] = 0.f;
	proj[8] = (r+l) / (r-l);proj[9] = (t+b)/(t-b);	proj[10]= (f+n)/(f-n); 		proj[11]= 1.f;
	proj[12]= 0.f;			proj[13] =0.f;			proj[14]= (-2.f*f*n)/(f-n);	proj[15]= 0.f;
}

static lm_bool lm_sampleHemisphere(
	int x, int y, int size, int side,
	float zNear, float zFar,
	lm_vec3 pos, lm_vec3 dir, lm_vec3 up,
	int *vp, float *view, float *proj)
{
	lm_vec3 right = lm_cross3(up, dir);
	// find the view parameters of the hemisphere side that we will render next
	// hemisphere layout in the framebuffer:
	//       +-------+---+---+-------+
	//       |       |   |   |   D   |
	//       |   C   | R | L +-------+
	//       |       |   |   |   U   |
	//       +-------+---+---+-------+
	switch (side)
	{
	case 0: // center
		lm_setView(vp, x, y, size, size,
				   view,     pos, dir, up,
				   proj,     -zNear, zNear, -zNear, zNear, zNear, zFar);
		break;
	case 1: // right
		lm_setView(vp, size + x, y, size / 2, size,
				   view,     pos, right, dir,
				   proj,     -zNear, 0.0f, -zNear, zNear, zNear, zFar);
		break;
	case 2: // left
		lm_setView(vp, size + x + size / 2, y, size / 2, size,
				   view,     pos, lm_negate3(right), dir,
				   proj,     0.0f, zNear, -zNear, zNear, zNear, zFar);
		break;
	case 3: // down
		lm_setView(vp, 2 * size + x, y + size / 2, size, size / 2,
				   view,     pos, lm_negate3(up), dir,
				   proj,     -zNear, zNear, 0.0f, zNear, zNear, zFar);
		break;
	case 4: // up
		lm_setView(vp, 2 * size + x, y, size, size / 2,
				   view,     pos, up, dir,
				   proj,     -zNear, zNear, -zNear, 0.0f, zNear, zFar);
		break;
	default:
		assert(LM_FALSE);
		break;
	}

	return LM_TRUE;
}

static lm_bool lmSampleHemisphere(lm_context *ctx, int* viewport, float* view, float* proj)
{
	// find the target position in the batch
	int x = (ctx->hemisphere.fbHemiIndex % ctx->hemisphere.fbHemiCountX) * ctx->hemisphere.size * 3;
	int y = (ctx->hemisphere.fbHemiIndex / ctx->hemisphere.fbHemiCountX) * ctx->hemisphere.size;

	int size = ctx->hemisphere.size;
	float zNear = ctx->hemisphere.zNear;
	float zFar = ctx->hemisphere.zFar;

	lm_vec3 pos = ctx->meshPosition.sample.position;
	lm_vec3 dir = ctx->meshPosition.sample.direction;
	lm_vec3 up = ctx->meshPosition.sample.up;

	return lm_sampleHemisphere(x, y, size,
			ctx->meshPosition.hemisphere.side,
			zNear, zFar,
			pos, dir, up, 
			viewport, view, proj);
}

static void lm_inverseTranspose(const float *m44, float *n33)
{
	if (!m44)
	{
		n33[0] = 1.0f; n33[1] = 0.0f; n33[2] = 0.0f;
		n33[3] = 0.0f; n33[4] = 1.0f; n33[5] = 0.0f;
		n33[6] = 0.0f; n33[7] = 0.0f; n33[8] = 1.0f;
		return;
	}

	float determinant = m44[ 0] * (m44[ 5] * m44[10] - m44[ 9] * m44[ 6])
					  - m44[ 1] * (m44[ 4] * m44[10] - m44[ 6] * m44[ 8])
					  + m44[ 2] * (m44[ 4] * m44[ 9] - m44[ 5] * m44[ 8]);

	assert(fabs(determinant) > FLT_EPSILON);
	float rcpDeterminant = 1.0f / determinant;

	n33[0] =  (m44[ 5] * m44[10] - m44[ 9] * m44[ 6]) * rcpDeterminant;
	n33[3] = -(m44[ 1] * m44[10] - m44[ 2] * m44[ 9]) * rcpDeterminant;
	n33[6] =  (m44[ 1] * m44[ 6] - m44[ 2] * m44[ 5]) * rcpDeterminant;
	n33[1] = -(m44[ 4] * m44[10] - m44[ 6] * m44[ 8]) * rcpDeterminant;
	n33[4] =  (m44[ 0] * m44[10] - m44[ 2] * m44[ 8]) * rcpDeterminant;
	n33[7] = -(m44[ 0] * m44[ 6] - m44[ 4] * m44[ 2]) * rcpDeterminant;
	n33[2] =  (m44[ 4] * m44[ 9] - m44[ 8] * m44[ 5]) * rcpDeterminant;
	n33[5] = -(m44[ 0] * m44[ 9] - m44[ 8] * m44[ 1]) * rcpDeterminant;
	n33[8] =  (m44[ 0] * m44[ 5] - m44[ 4] * m44[ 1]) * rcpDeterminant;
}

static lm_vec3 lm_transformNormal(const float *m, lm_vec3 n)
{
	lm_vec3 r;
	r.x = m[0] * n.x + m[3] * n.y + m[6] * n.z;
	r.y = m[1] * n.x + m[4] * n.y + m[7] * n.z;
	r.z = m[2] * n.x + m[5] * n.y + m[8] * n.z;
	return r;
}

static lm_vec3 lm_transformPosition(const float *m, lm_vec3 v)
{
	if (!m)
		return v;
	lm_vec3 r;
	r.x =     m[0] * v.x + m[4] * v.y + m[ 8] * v.z + m[12];
	r.y =     m[1] * v.x + m[5] * v.y + m[ 9] * v.z + m[13];
	r.z =     m[2] * v.x + m[6] * v.y + m[10] * v.z + m[14];
	float d = m[3] * v.x + m[7] * v.y + m[11] * v.z + m[15];
	assert(lm_absf(d - 1.0f) < 0.00001f); // could divide by d, but this shouldn't be a projection transform!
	return r;
}

static lm_bool lm_isRasterizerPositionValid(lm_context *ctx)
{
	return	ctx->meshPosition.rasterizer.x <= ctx->meshPosition.rasterizer.maxx &&
			ctx->meshPosition.rasterizer.y <= ctx->meshPosition.rasterizer.maxy;
}

static void lm_initMeshRasterizerPosition(lm_context *ctx)
{
	// load and transform triangle to process next
	lm_vec2 uvMin = lm_v2(FLT_MAX, FLT_MAX), uvMax = lm_v2(-FLT_MAX, -FLT_MAX);
	lm_vec2 uvScale = lm_v2i(ctx->lightmap.width, ctx->lightmap.height);
	uint32_t vIndices[3];
	for (int i = 0; i < 3; i++)
	{
		// decode index
		uint32_t vIndex;
		switch (ctx->mesh.indicesType)
		{
		case LM_NONE:
			vIndex = ctx->meshPosition.triangle.baseIndex + i;
			break;
		case LM_UNSIGNED_BYTE:
			vIndex = ((const uint8_t*)ctx->mesh.indices + ctx->meshPosition.triangle.baseIndex)[i];
			break;
		case LM_UNSIGNED_SHORT:
			vIndex = ((const unsigned short*)ctx->mesh.indices + ctx->meshPosition.triangle.baseIndex)[i];
			break;
		case LM_UNSIGNED_INT:
			vIndex = ((const uint32_t*)ctx->mesh.indices + ctx->meshPosition.triangle.baseIndex)[i];
			break;
		default:
			assert(LM_FALSE);
			break;
		}
		vIndices[i] = vIndex;

		// decode and pre-transform vertex position
		const void *pPtr = ctx->mesh.positions + vIndex * ctx->mesh.positionsStride;
		lm_vec3 p;
		switch (ctx->mesh.positionsType)
		{
		// TODO: signed formats
		case LM_UNSIGNED_BYTE: {
			const uint8_t *uc = (const uint8_t*)pPtr;
			p = lm_v3(uc[0], uc[1], uc[2]);
		} break;
		case LM_UNSIGNED_SHORT: {
			const unsigned short *us = (const unsigned short*)pPtr;
			p = lm_v3(us[0], us[1], us[2]);
		} break;
		case LM_UNSIGNED_INT: {
			const uint32_t *ui = (const uint32_t*)pPtr;
			p = lm_v3((float)ui[0], (float)ui[1], (float)ui[2]);
		} break;
		case LM_FLOAT: {
			p = *(const lm_vec3*)pPtr;
		} break;
		default: {
			assert(LM_FALSE);
		} break;
		}
		ctx->meshPosition.triangle.p[i] = lm_transformPosition(ctx->mesh.modelMatrix, p);

		// decode and scale (to lightmap resolution) vertex lightmap texture coords
		const void *uvPtr = ctx->mesh.uvs + vIndex * ctx->mesh.uvsStride;
		lm_vec2 uv;
		switch (ctx->mesh.uvsType)
		{
		case LM_UNSIGNED_BYTE: {
			const uint8_t *uc = (const uint8_t*)uvPtr;
			uv = lm_v2(uc[0] / (float)UCHAR_MAX, uc[1] / (float)UCHAR_MAX);
		} break;
		case LM_UNSIGNED_SHORT: {
			const unsigned short *us = (const unsigned short*)uvPtr;
			uv = lm_v2(us[0] / (float)USHRT_MAX, us[1] / (float)USHRT_MAX);
		} break;
		case LM_UNSIGNED_INT: {
			const uint32_t *ui = (const uint32_t*)uvPtr;
			uv = lm_v2(ui[0] / (float)UINT_MAX, ui[1] / (float)UINT_MAX);
		} break;
		case LM_FLOAT: {
			uv = *(const lm_vec2*)uvPtr;
		} break;
		default: {
			assert(LM_FALSE);
		} break;
		}

		ctx->meshPosition.triangle.uv[i] = lm_mul2(lm_pmod2(uv, 1.0f), uvScale); // maybe clamp to 0.0-1.0 instead of pmod?

		// update bounds on lightmap
		uvMin = lm_min2(uvMin, ctx->meshPosition.triangle.uv[i]);
		uvMax = lm_max2(uvMax, ctx->meshPosition.triangle.uv[i]);
	}

	lm_vec3 flatNormal = lm_cross3(
		lm_sub3(ctx->meshPosition.triangle.p[2], ctx->meshPosition.triangle.p[0]),
		lm_sub3(ctx->meshPosition.triangle.p[1], ctx->meshPosition.triangle.p[0]));

	for (int i = 0; i < 3; i++)
	{
		// decode and pre-transform vertex normal
		const void *nPtr = ctx->mesh.normals + vIndices[i] * ctx->mesh.normalsStride;
		lm_vec3 n;
		switch (ctx->mesh.normalsType)
		{
		// TODO: signed formats
		case LM_FLOAT: {
			n = *(const lm_vec3*)nPtr;
		} break;
		case LM_NONE: {
			n = flatNormal;
		} break;
		default: {
			assert(LM_FALSE);
		} break;
		}
		ctx->meshPosition.triangle.n[i] = lm_normalize3(lm_transformNormal(ctx->mesh.normalMatrix, n));
	}

	// calculate area of interest (on lightmap) for conservative rasterization
	lm_vec2 bbMin = lm_floor2(uvMin);
	lm_vec2 bbMax = lm_ceil2 (uvMax);
	ctx->meshPosition.rasterizer.minx = lm_maxi((int)bbMin.x - 1, 0);
	ctx->meshPosition.rasterizer.miny = lm_maxi((int)bbMin.y - 1, 0);
	ctx->meshPosition.rasterizer.maxx = lm_mini((int)bbMax.x + 1, ctx->lightmap.width - 1);
	ctx->meshPosition.rasterizer.maxy = lm_mini((int)bbMax.y + 1, ctx->lightmap.height - 1);
	assert(ctx->meshPosition.rasterizer.minx <= ctx->meshPosition.rasterizer.maxx &&
		   ctx->meshPosition.rasterizer.miny <= ctx->meshPosition.rasterizer.maxy);
	ctx->meshPosition.rasterizer.x = ctx->meshPosition.rasterizer.minx + lm_passOffsetX(ctx);
	ctx->meshPosition.rasterizer.y = ctx->meshPosition.rasterizer.miny + lm_passOffsetY(ctx);

	if (!lm_isRasterizerPositionValid(ctx))
	{
		lm_moveToNextPotentialConservativeTriangleRasterizerPosition(ctx);
	}
	// // try moving to first valid sample position
	// if (ctx->meshPosition.rasterizer.x <= ctx->meshPosition.rasterizer.maxx &&
	// 	ctx->meshPosition.rasterizer.y <= ctx->meshPosition.rasterizer.maxy &&
	// 	lm_findFirstConservativeTriangleRasterizerPosition(ctx))
	// 	ctx->meshPosition.hemisphere.side = 0; // we can start sampling the hemisphere
	// else
	// 	ctx->meshPosition.hemisphere.side = 5; // no samples on this triangle! put hemisphere sampler into finished state
}

void lmFramebufferHemiCount(lm_context *ctx, int *hemix, int *hemiy)
{
	*hemix = ctx->hemisphere.fbHemiCountX;
	*hemiy = ctx->hemisphere.fbHemiCountY;
}

void lmFramebufferSize(int *w, int *h)
{
	const int size = HEMI_FRAMEBUFFER_UNIT_SIZE;
	*w = HEMI_FRAMEBUFFER_UNIT_SIZE * 3;
	*h = HEMI_FRAMEBUFFER_UNIT_SIZE;
}

void lmHemiCount(int hemiSize, int *X, int *Y)
{
	int fbw, fbh;
	lmFramebufferSize(&fbw, &fbh);
	*X = fbw / (3 * hemiSize);
	*Y = fbh / hemiSize;
}

lm_context *lmCreate(int hemisphereSize, float zNear, float zFar,
	int interpolationPasses, float interpolationThreshold,
	float cameraToSurfaceDistanceModifier)
{
	assert(hemisphereSize == 512 || hemisphereSize == 256 || hemisphereSize == 128 ||
		   hemisphereSize ==  64 || hemisphereSize ==  32 || hemisphereSize ==  16);
	assert(zNear < zFar && zNear > 0.0f);
	assert(cameraToSurfaceDistanceModifier >= -1.0f);
	assert(interpolationPasses >= 0 && interpolationPasses <= 8);
	assert(interpolationThreshold >= 0.0f);

	lm_context *ctx = (lm_context*)LM_CALLOC(1, sizeof(lm_context));

	ctx->meshPosition.passCount = 1 + 3 * interpolationPasses;
	ctx->interpolationThreshold = interpolationThreshold;
	ctx->hemisphere.size = hemisphereSize;
	ctx->hemisphere.zNear = zNear;
	ctx->hemisphere.zFar = zFar;
	ctx->hemisphere.cameraToSurfaceDistanceModifier = cameraToSurfaceDistanceModifier;
	ctx->hemisphere.storage.width = ctx->hemisphere.storage.height = UINT16_MAX;

	// calculate hemisphere batch size
	ctx->hemisphere.fbHemiCountX = 1536 / (3 * ctx->hemisphere.size);
	ctx->hemisphere.fbHemiCountY = 512 / ctx->hemisphere.size;

	// allocate batchPosition-to-lightmapPosition map
	ctx->hemisphere.fbHemiToLightmapLocation = (lm_ivec2*)LM_CALLOC(ctx->hemisphere.fbHemiCountX * ctx->hemisphere.fbHemiCountY, sizeof(lm_ivec2));
	return ctx;
}

void lmDestroy(lm_context *ctx)
{
	//TODO: move lua
	//lm_destroyGPUData(ctx);
	// free memory
	LM_FREE(ctx->hemisphere.storage.toLightmapLocation);
	LM_FREE(ctx->hemisphere.fbHemiToLightmapLocation);
#ifdef LM_DEBUG_INTERPOLATION
	LM_FREE(ctx->lightmap.debug);
#endif
	LM_FREE(ctx);
}

void lmSetTargetLightmap(lm_context *ctx, float *outLightmap, uint16_t w, uint16_t h, uint8_t c)
{
	ctx->lightmap.data = outLightmap;
	ctx->lightmap.width = w;
	ctx->lightmap.height = h;
	ctx->lightmap.channels = c;

	//lm_checkSetTargetLightmap(ctx, w, h);
	// allocate storage position to lightmap position map
	if (ctx->hemisphere.storage.toLightmapLocation)
		LM_FREE(ctx->hemisphere.storage.toLightmapLocation);
	ctx->hemisphere.storage.width = w > ctx->hemisphere.fbHemiCountX ? w : ctx->hemisphere.fbHemiCountX;
	ctx->hemisphere.storage.height = h > ctx->hemisphere.fbHemiCountY ? h : ctx->hemisphere.fbHemiCountY;
	uint32_t num = ctx->hemisphere.storage.width * ctx->hemisphere.storage.height;
	ctx->hemisphere.storage.toLightmapLocation = (lm_ivec2*)LM_CALLOC(num, sizeof(lm_ivec2));
	// invalidate all positions
	for (uint32_t i = 0; i < num; ++i)
		ctx->hemisphere.storage.toLightmapLocation[i].x = -1;

#ifdef LM_DEBUG_INTERPOLATION
	if (ctx->lightmap.debug)
		LM_FREE(ctx->lightmap.debug);
	ctx->lightmap.debug = (uint8_t*)LM_CALLOC(ctx->lightmap.width * ctx->lightmap.height, 3);
#endif
}

void lmSetGeometry(lm_context *ctx,
	const float *transformationMatrix,
	lm_type positionsType, const void *positionsXYZ, int positionsStride,
	lm_type normalsType, const void *normalsXYZ, int normalsStride,
	lm_type lightmapCoordsType, const void *lightmapCoordsUV, int lightmapCoordsStride,
	int count, lm_type indicesType, const void *indices)
{
	ctx->mesh.modelMatrix = transformationMatrix;
	ctx->mesh.positions = (const uint8_t*)positionsXYZ;
	ctx->mesh.positionsType = positionsType;
	ctx->mesh.positionsStride = positionsStride == 0 ? sizeof(lm_vec3) : positionsStride;
	ctx->mesh.normals = (const uint8_t*)normalsXYZ;
	ctx->mesh.normalsType = normalsType;
	ctx->mesh.normalsStride = normalsStride == 0 ? sizeof(lm_vec3) : normalsStride;
	ctx->mesh.uvs = (const uint8_t*)lightmapCoordsUV;
	ctx->mesh.uvsType = lightmapCoordsType;
	ctx->mesh.uvsStride = lightmapCoordsStride == 0 ? sizeof(lm_vec2) : lightmapCoordsStride;
	ctx->mesh.indicesType = indicesType;
	ctx->mesh.indices = (const uint8_t*)indices;
	ctx->mesh.count = count;

	lm_inverseTranspose(transformationMatrix, ctx->mesh.normalMatrix);
}

lm_bool lmBake(lm_context *ctx)
{
	//	foreach pass
	//		foreach triangle in mesh
	//			foreach pos in triangle 
	//				foreach side in hemicube
	//					set camera view and projection
	//					set viewport
	//					render scene
	//				end hemicube
	//				intgerate hemisphere
	//			end triangle
	//		endmesh
	//		store info to lightmap
	//	end pass

	for (ctx->meshPosition.pass = 0; 
		ctx->meshPosition.pass < ctx->meshPosition.passCount; 
		++ctx->meshPosition.pass)
	{
		for (ctx->meshPosition.triangle.baseIndex=0; 
			ctx->meshPosition.triangle.baseIndex + 3 < ctx->mesh.count;
			ctx->meshPosition.triangle.baseIndex += 3)
		{
			for(lm_initMeshRasterizerPosition(ctx);
				!lm_hasConservativeTriangleRasterizerFinished(ctx);
				lm_moveToNextPotentialConservativeTriangleRasterizerPosition(ctx))
			{
				if (!lm_trySamplingConservativeTriangleRasterizerPosition(ctx))
					continue;

				if (ctx->hemisphere.fbHemiIndex == 0)
					ctx->render.init_buffer(ctx);

				ctx->hemisphere.fbHemiToLightmapLocation[ctx->hemisphere.fbHemiIndex] =
				lm_i2(ctx->meshPosition.rasterizer.x, ctx->meshPosition.rasterizer.y);

				for (ctx->meshPosition.hemisphere.side=0; 
					ctx->meshPosition.hemisphere.side < 5;
					++ctx->meshPosition.hemisphere.side)
				{
					int outViewport4[4];
					float outView4x4[16];
					float outProjection4x4[16];
					lmSampleHemisphere(ctx, outViewport4, outView4x4, outProjection4x4);
					//render scene
					ctx->render.render_scene(ctx, outViewport4, outView4x4, outProjection4x4);
				}

				// finish hemisphere
				if (++ctx->hemisphere.fbHemiIndex == ctx->hemisphere.fbHemiCountX * ctx->hemisphere.fbHemiCountY)
				{
					// downsample new hemisphere batch and store the results
					lm_integrateHemisphereBatch(ctx);
				}

				ctx->render.process(ctx);
			}
		}
		if (0 != ctx->hemisphere.fbHemiIndex)
			lm_integrateHemisphereBatch(ctx);
	}

	assert(ctx->meshPosition.triangle.baseIndex+3 == ctx->mesh.count);
	return LM_TRUE;
}

float lmProgress(lm_context *ctx)
{
	float passProgress = (float)ctx->meshPosition.triangle.baseIndex / (float)ctx->mesh.count;
	return ((float)ctx->meshPosition.pass + passProgress) / (float)ctx->meshPosition.passCount;
}

// these are not performance tuned since their impact on the whole lightmapping duration is insignificant
float lmImageMin(const float *image, int w, int h, int c, int m)
{
	assert(c > 0 && m);
	float minValue = FLT_MAX;
	for (int i = 0; i < w * h; i++)
		for (int j = 0; j < c; j++)
			if (m & (1 << j))
				minValue = lm_minf(minValue, image[i * c + j]);
	return minValue;
}

float lmImageMax(const float *image, int w, int h, int c, int m)
{
	assert(c > 0 && m);
	float maxValue = 0.0f;
	for (int i = 0; i < w * h; i++)
		for (int j = 0; j < c; j++)
			if (m & (1 << j))
				maxValue = lm_maxf(maxValue, image[i * c + j]);
	return maxValue;
}

void lmImageAdd(float *image, int w, int h, int c, float value, int m)
{
	assert(c > 0 && m);
	for (int i = 0; i < w * h; i++)
		for (int j = 0; j < c; j++)
			if (m & (1 << j))
				image[i * c + j] += value;
}

void lmImageScale(float *image, int w, int h, int c, float factor, int m)
{
	assert(c > 0 && m);
	for (int i = 0; i < w * h; i++)
		for (int j = 0; j < c; j++)
			if (m & (1 << j))
				image[i * c + j] *= factor;
}

void lmImagePower(float *image, int w, int h, int c, float exponent, int m)
{
	assert(c > 0 && m);
	for (int i = 0; i < w * h; i++)
		for (int j = 0; j < c; j++)
			if (m & (1 << j))
				image[i * c + j] = powf(image[i * c + j], exponent);
}

void lmImageDilate(const float *image, float *outImage, int w, int h, int c)
{
	assert(c > 0 && c <= 4);
	for (int y = 0; y < h; y++)
	{
		for (int x = 0; x < w; x++)
		{
			float color[4];
			lm_bool valid = LM_FALSE;
			for (int i = 0; i < c; i++)
			{
				color[i] = image[(y * w + x) * c + i];
				valid |= color[i] > 0.0f;
			}
			if (!valid)
			{
				int n = 0;
				const int dx[] = { -1, 0, 1,  0 };
				const int dy[] = {  0, 1, 0, -1 };
				for (int d = 0; d < 4; d++)
				{
					int cx = x + dx[d];
					int cy = y + dy[d];
					if (cx >= 0 && cx < w && cy >= 0 && cy < h)
					{
						float dcolor[4];
						lm_bool dvalid = LM_FALSE;
						for (int i = 0; i < c; i++)
						{
							dcolor[i] = image[(cy * w + cx) * c + i];
							dvalid |= dcolor[i] > 0.0f;
						}
						if (dvalid)
						{
							for (int i = 0; i < c; i++)
								color[i] += dcolor[i];
							n++;
						}
					}
				}
				if (n)
				{
					float in = 1.0f / n;
					for (int i = 0; i < c; i++)
						color[i] *= in;
				}
			}
			for (int i = 0; i < c; i++)
				outImage[(y * w + x) * c + i] = color[i];
		}
	}
}

void lmImageSmooth(const float *image, float *outImage, int w, int h, int c)
{
	assert(c > 0 && c <= 4);
	for (int y = 0; y < h; y++)
	{
		for (int x = 0; x < w; x++)
		{
			float color[4] = {0};
			int n = 0;
			for (int dy = -1; dy <= 1; dy++)
			{
				int cy = y + dy;
				for (int dx = -1; dx <= 1; dx++)
				{
					int cx = x + dx;
					if (cx >= 0 && cx < w && cy >= 0 && cy < h)
					{
						lm_bool valid = LM_FALSE;
						for (int i = 0; i < c; i++)
							valid |= image[(cy * w + cx) * c + i] > 0.0f;
						if (valid)
						{
							for (int i = 0; i < c; i++)
								color[i] += image[(cy * w + cx) * c + i];
							n++;
						}
					}
				}
			}
			for (int i = 0; i < c; i++)
				outImage[(y * w + x) * c + i] = n ? color[i] / n : 0.0f;
		}
	}
}

void lmImageDownsample(const float *image, float *outImage, int w, int h, int c)
{
	assert(c > 0 && c <= 4);
	for (int y = 0; y < h / 2; y++)
	{
		for (int x = 0; x < w / 2; x++)
		{
			int p0 = 2 * (y * w + x) * c;
			int p1 = p0 + w * c;
			int valid[2][2] = {0};
			float sums[4] = {0};
			for (int i = 0; i < c; i++)
			{
				valid[0][0] |= image[p0     + i] != 0.0f ? 1 : 0;
				valid[0][1] |= image[p0 + c + i] != 0.0f ? 1 : 0;
				valid[1][0] |= image[p1     + i] != 0.0f ? 1 : 0;
				valid[1][1] |= image[p1 + c + i] != 0.0f ? 1 : 0;
				sums[i] += image[p0 + i] + image[p0 + c + i] + image[p1 + i] + image[p1 + c + i];
			}
			int n = valid[0][0] + valid[0][1] + valid[1][0] + valid[1][1];
			int p = (y * w / 2 + x) * c;
			for (int i = 0; i < c; i++)
				outImage[p + i] = n ? sums[i] / n : 0.0f;
		}
	}
}

void lmImageFtoUB(const float *image, uint8_t *outImage, int w, int h, int c, float max)
{
	assert(c > 0);
	float scale = 255.0f / (max != 0.0f ? max : lmImageMax(image, w, h, c, LM_ALL_CHANNELS));
	for (int i = 0; i < w * h * c; i++)
		outImage[i] = (uint8_t)lm_minf(lm_maxf(image[i] * scale, 0.0f), 255.0f);
}

// TGA output helpers
static void lm_swapRandBub(uint8_t *image, int w, int h, int c)
{
	assert(c >= 3);
	for (int i = 0; i < w * h * c; i += c)
		LM_SWAP(uint8_t, image[i], image[i + 2]);
}

lm_bool lmImageSaveTGAub(const char *filename, const uint8_t *image, int w, int h, int c)
{
	assert(c == 1 || c == 3 || c == 4);
	lm_bool isGreyscale = c == 1;
	lm_bool hasAlpha = c == 4;
	uint8_t header[18] = {
		0, 0, (uint8_t)(isGreyscale ? 3 : 2), 0, 0, 0, 0, 0, 0, 0, 0, 0,
		(uint8_t)(w & 0xff), (uint8_t)((w >> 8) & 0xff), (uint8_t)(h & 0xff), (uint8_t)((h >> 8) & 0xff),
		(uint8_t)(8 * c), (uint8_t)(hasAlpha ? 8 : 0)
	};
#if defined(_MSC_VER) && _MSC_VER >= 1400
	FILE *file;
	if (fopen_s(&file, filename, "wb") != 0) return LM_FALSE;
#else
	FILE *file = fopen(filename, "wb");
	if (!file) return LM_FALSE;
#endif
	fwrite(header, 1, sizeof(header), file);

	// we make sure to swap it back! trust me. :)
	if (!isGreyscale)
		lm_swapRandBub((uint8_t*)image, w, h, c);
	fwrite(image, 1, w * h * c , file);
	if (!isGreyscale)
		lm_swapRandBub((uint8_t*)image, w, h, c);

	fclose(file);
	return LM_TRUE;
}

lm_bool lmImageSaveTGAf(const char *filename, const float *image, int w, int h, int c, float max)
{
	uint8_t *temp = (uint8_t*)LM_CALLOC(w * h * c, sizeof(uint8_t));
	lmImageFtoUB(image, temp, w, h, c, max);
	lm_bool success = lmImageSaveTGAub(filename, temp, w, h, c);
	LM_FREE(temp);
	return success;
}

#endif // LIGHTMAPPER_IMPLEMENTATION
