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
#ifdef USE_BGFX
#define LM_UNSIGNED_BYTE  1
#define LM_UNSIGNED_SHORT 2
#define LM_UNSIGNED_INT   3
#define LM_FLOAT          4
#else
#define LM_UNSIGNED_BYTE  GL_UNSIGNED_BYTE
#define LM_UNSIGNED_SHORT GL_UNSIGNED_SHORT
#define LM_UNSIGNED_INT   GL_UNSIGNED_INT
#define LM_FLOAT          GL_FLOAT
#endif


typedef struct lm_context lm_context;

// creates a lightmapper instance. it can be used to render multiple lightmaps.
lm_context *lmCreate(
	int hemisphereSize,                                                                                // hemisphereSize: resolution of the hemisphere renderings. must be a power of two! typical: 64.
	float zNear, float zFar,                                                                           // zNear/zFar: hemisphere min/max draw distances.
	float clearR, float clearG, float clearB,                                                          // clear color / background color / sky color.
	int interpolationPasses, float interpolationThreshold,                                             // passes: hierarchical selective interpolation passes (0-8; initial step size = 2^passes).
	                                                                                                   // threshold: error value below which lightmap pixels are interpolated instead of rendered.
	                                                                                                   // use output image from LM_DEBUG_INTERPOLATION to determine a good value.
	                                                                                                   // values around and below 0.01 are probably ok.
	                                                                                                   // the lower the value, the more hemispheres are rendered -> slower, but possibly better quality.
	float cameraToSurfaceDistanceModifier LM_DEFAULT_VALUE(0.0f));                                     // modifier for the height of the rendered hemispheres above the surface
	                                                                                                   // -1.0f => stick to surface, 0.0f => minimum height for interpolated surface normals,
	                                                                                                   // > 0.0f => improves gradients on surfaces with interpolated normals due to the flat surface horizon,
	                                                                                                   // but may introduce other artifacts.

// optional: set material characteristics by specifying cos(theta)-dependent weights for incoming light.
typedef float (*lm_weight_func)(float cos_theta, void *userdata);
void lmSetHemisphereWeights(lm_context *ctx, lm_weight_func f, void *userdata);                        // precalculates weights for incoming light depending on its angle. (default: all weights are 1.0f)

// specify an output lightmap image buffer with w * h * c * sizeof(float) bytes of memory.
void lmSetTargetLightmap(lm_context *ctx, float *outLightmap, int w, int h, int c);                    // output HDR lightmap (linear 32bit float channels; c: 1->Greyscale, 2->Greyscale+Alpha, 3->RGB, 4->RGBA).

// set the geometry to map to the currently set target lightmap (set the target lightmap before calling this!).
void lmSetGeometry(lm_context *ctx,
	const float *transformationMatrix,                                                                 // 4x4 object-to-world transform for the geometry or NULL (no transformation).
	lm_type positionsType, const void *positionsXYZ, int positionsStride,                              // triangle mesh in object space.
	lm_type normalsType, const void *normalsXYZ, int normalsStride,                                    // optional normals for the mesh in object space (Use LM_NONE type in case you only need flat surfaces).
	lm_type lightmapCoordsType, const void *lightmapCoordsUV, int lightmapCoordsStride,                // lightmap atlas texture coordinates for the mesh [0..1]x[0..1] (integer types are normalized to 0..1 range).
	int count, lm_type indicesType LM_DEFAULT_VALUE(LM_NONE), const void *indices LM_DEFAULT_VALUE(0));// if mesh indices are used, count = number of indices else count = number of vertices.

#ifdef USE_BGFX
void lmSetDownsampleShaderingInfo(lm_context *ctx,
	bgfx_view_id_t viewid_base, uint16_t viewid_count, bgfx_view_id_t storage_viewid,
	bgfx_program_handle_t weightDownsampleProg, bgfx_uniform_handle_t weightHemisphereTextureHandle, bgfx_uniform_handle_t weightTextureHandle,
	bgfx_program_handle_t downsampleProg, bgfx_uniform_handle_t hemisphereTextureHanle);
#endif

// as long as lmBegin returns true, the scene has to be rendered with the
// returned camera and view parameters to the currently bound framebuffer.
// if lmBegin returns true, it must be followed by lmEnd after rendering!
lm_bool lmBegin(lm_context *ctx,
	int* outViewport4,                                                                                 // output of the current viewport: { x, y, w, h }. use these to call glViewport()!
	float* outView4x4,                                                                                 // output of the current camera view matrix.
	float* outProjection4x4);                                                                          // output of the current camera projection matrix.

float lmProgress(lm_context *ctx);                                                                     // should only be called between lmBegin/lmEnd!
                                                                                                       // provides the light mapping progress as a value increasing from 0.0 to 1.0.

void lmEnd(lm_context *ctx);

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
void lmImageFtoUB(const float *image, unsigned char *outImage, int w, int h, int c, float max LM_DEFAULT_VALUE(0.0f)); // casts a floating point image to an 8bit/channel image

// TGA file output helpers
lm_bool lmImageSaveTGAub(const char *filename, const unsigned char *image, int w, int h, int c);
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

typedef struct lm_ivec2 { int x, y; } lm_ivec2;
static inline lm_ivec2 lm_i2        (int     x, int     y) { lm_ivec2 v = { x, y }; return v; }

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

struct progromCode{
		const char *vs, *fs;
		uint32_t vssize, fssize;
};

struct lm_context
{
	struct
	{
		const float *modelMatrix;
		float normalMatrix[9];

		const unsigned char *positions;
		lm_type positionsType;
		int positionsStride;
		const unsigned char *normals;
		lm_type normalsType;
		int normalsStride;
		const unsigned char *uvs;
		lm_type uvsType;
		int uvsStride;
		const unsigned char *indices;
		lm_type indicesType;
		unsigned int count;
	} mesh;

	struct
	{
		int pass;
		int passCount;

		struct
		{
			unsigned int baseIndex;
			lm_vec3 p[3];
			lm_vec3 n[3];
			lm_vec2 uv[3];
		} triangle;

		struct
		{
			int minx, miny;
			int maxx, maxy;
			int x, y;
		} rasterizer;

		struct
		{
			lm_vec3 position;
			lm_vec3 direction;
			lm_vec3 up;
		} sample;

		struct
		{
			int side;
		} hemisphere;
	} meshPosition;

	struct
	{
		int width;
		int height;
		int channels;
		float *data;

#ifdef LM_DEBUG_INTERPOLATION
		unsigned char *debug;
#endif
	} lightmap;

	struct
	{
		uint32_t size;
		float zNear, zFar;
		float cameraToSurfaceDistanceModifier;
		struct { float r, g, b; } clearColor;

		uint32_t fbHemiCountX;
		uint32_t fbHemiCountY;
		uint32_t fbHemiIndex;
		lm_ivec2 *fbHemiToLightmapLocation;
#ifdef USE_BGFX
		struct {
			bgfx_view_id_t	base;
			uint16_t count;
		}viewids;
		bgfx_view_id_t			storage_viewid;
		bgfx_frame_buffer_handle_t	fb[2];
		bgfx_texture_handle_t	rbTexture[2];
		bgfx_texture_handle_t	rbDepth;

		bgfx_transient_vertex_buffer_t tvb;

		struct {
			bgfx_program_handle_t	prog;
			bgfx_uniform_handle_t	hemispheresTextureHandle;

			bgfx_uniform_handle_t	weightsTextureHandle;
			bgfx_texture_handle_t	weightsTexture;
		} firstPass;

		struct {
			bgfx_program_handle_t prog;
			bgfx_uniform_handle_t hemispheresTextureHandle;
		} downsamplePass;

		struct
		{
			bgfx_texture_handle_t texture;
			lm_ivec2 writePosition;
			lm_ivec2 *toLightmapLocation;
		} storage;
#else
		GLuint fbTexture[2];
		GLuint fb[2];
		GLuint fbDepth;
		GLuint vao;
		struct
		{
			GLuint programID;
			GLuint hemispheresTextureID;
			GLuint weightsTextureID;
			GLuint weightsTexture;
		} firstPass;
		struct
		{
			GLuint programID;
			GLuint hemispheresTextureID;
		} downsamplePass;
		struct
		{
			GLuint texture;
			lm_ivec2 writePosition;
			lm_ivec2 *toLightmapLocation;
		} storage;
#endif 
	} hemisphere;

	float interpolationThreshold;
};

// pass order of one 4x4 interpolation patch for two interpolation steps (and the next neighbors right of/below it)
// 0 4 1 4 0
// 5 6 5 6 5
// 2 4 3 4 2
// 5 6 5 6 5
// 0 4 1 4 0

static unsigned int lm_passStepSize(lm_context *ctx)
{
	unsigned int shift = ctx->meshPosition.passCount / 3 - (ctx->meshPosition.pass - 1) / 3;
	unsigned int step = (1 << shift);
	assert(step > 0);
	return step;
}

static unsigned int lm_passOffsetX(lm_context *ctx)
{
	if (!ctx->meshPosition.pass)
		return 0;
	int passType = (ctx->meshPosition.pass - 1) % 3;
	unsigned int halfStep = lm_passStepSize(ctx) >> 1;
	return passType != 1 ? halfStep : 0;
}

static unsigned int lm_passOffsetY(lm_context *ctx)
{
	if (!ctx->meshPosition.pass)
		return 0;
	int passType = (ctx->meshPosition.pass - 1) % 3;
	unsigned int halfStep = lm_passStepSize(ctx) >> 1;
	return passType != 0 ? halfStep : 0;
}

static lm_bool lm_hasConservativeTriangleRasterizerFinished(lm_context *ctx)
{
	return ctx->meshPosition.rasterizer.y >= ctx->meshPosition.rasterizer.maxy;
}

static void lm_moveToNextPotentialConservativeTriangleRasterizerPosition(lm_context *ctx)
{
	unsigned int step = lm_passStepSize(ctx);
	ctx->meshPosition.rasterizer.x += step;
	while (ctx->meshPosition.rasterizer.x >= ctx->meshPosition.rasterizer.maxx)
	{
		ctx->meshPosition.rasterizer.x = ctx->meshPosition.rasterizer.minx + lm_passOffsetX(ctx);
		ctx->meshPosition.rasterizer.y += step;
		if (lm_hasConservativeTriangleRasterizerFinished(ctx))
			break;
	}
}

static float *lm_getLightmapPixel(lm_context *ctx, int x, int y)
{
	assert(x >= 0 && x < ctx->lightmap.width && y >= 0 && y < ctx->lightmap.height);
	return ctx->lightmap.data + (y * ctx->lightmap.width + x) * ctx->lightmap.channels;
}

static void lm_setLightmapPixel(lm_context *ctx, int x, int y, float *in)
{
	assert(x >= 0 && x < ctx->lightmap.width && y >= 0 && y < ctx->lightmap.height);
	float *p = ctx->lightmap.data + (y * ctx->lightmap.width + x) * ctx->lightmap.channels;
	for (int j = 0; j < ctx->lightmap.channels; j++)
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
	if (lm_hasConservativeTriangleRasterizerFinished(ctx))
		return LM_FALSE;

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
	ctx->meshPosition.sample.direction = lm_normalize3(ctx->meshPosition.sample.direction);
	float cameraToSurfaceDistance = (1.0f + ctx->hemisphere.cameraToSurfaceDistanceModifier) * ctx->hemisphere.zNear * sqrtf(2.0f);
	ctx->meshPosition.sample.position = lm_add3(ctx->meshPosition.sample.position, lm_scale3(ctx->meshPosition.sample.direction, cameraToSurfaceDistance));

	if (!lm_finite3(ctx->meshPosition.sample.position) ||
		!lm_finite3(ctx->meshPosition.sample.direction) ||
		lm_length3sq(ctx->meshPosition.sample.direction) < 0.5f) // don't allow 0.0f. should always be ~1.0f
		return LM_FALSE;

	lm_vec3 up = lm_v3(0.0f, 1.0f, 0.0f);
	if (lm_absf(lm_dot3(up, ctx->meshPosition.sample.direction)) > 0.8f)
		up = lm_v3(0.0f, 0.0f, 1.0f);

#if 0
	// triangle-consistent up vector
	ctx->meshPosition.sample.up = lm_normalize3(lm_cross3(up, ctx->meshPosition.sample.direction));
	return LM_TRUE;
#else
	// "randomized" rotation with pattern
	lm_vec3 side = lm_normalize3(lm_cross3(up, ctx->meshPosition.sample.direction));
	up = lm_normalize3(lm_cross3(side, ctx->meshPosition.sample.direction));
	int rx = ctx->meshPosition.rasterizer.x % 3;
	int ry = ctx->meshPosition.rasterizer.y % 3;
	static const float lm_pi = 3.14159265358979f;
	float phi = 2.0f * lm_pi * lm_baseAngles[ry][rx] + 0.1f * ((float)rand() / (float)RAND_MAX);
	ctx->meshPosition.sample.up = lm_normalize3(lm_add3(lm_scale3(side, cosf(phi)), lm_scale3(up, sinf(phi))));
	return LM_TRUE;
#endif
}

// returns true if a sampling position was found and
// false if we finished rasterizing the current triangle
static lm_bool lm_findFirstConservativeTriangleRasterizerPosition(lm_context *ctx)
{
	while (!lm_trySamplingConservativeTriangleRasterizerPosition(ctx))
	{
		lm_moveToNextPotentialConservativeTriangleRasterizerPosition(ctx);
		if (lm_hasConservativeTriangleRasterizerFinished(ctx))
			return LM_FALSE;
	}
	return LM_TRUE;
}

static lm_bool lm_findNextConservativeTriangleRasterizerPosition(lm_context *ctx)
{
	lm_moveToNextPotentialConservativeTriangleRasterizerPosition(ctx);
	return lm_findFirstConservativeTriangleRasterizerPosition(ctx);
}

static void lm_downsample(lm_context *ctx)
{
	int fbRead = 0;
	int fbWrite = 1;

	// weighted downsampling pass
	int outHemiSize = ctx->hemisphere.size / 2;

#ifdef USE_BGFX
	// render state will not discard
	BGFX(set_state)(BGFX_STATE_DEPTH_TEST_NEVER|BGFX_STATE_WRITE_RGB|BGFX_STATE_WRITE_A, 0);
	BGFX(set_transient_vertex_buffer)(0, &ctx->hemisphere.tvb, 0, 4);
	const uint32_t discardStates = BGFX_DISCARD_TRANSFORM|BGFX_DISCARD_STATE;

	bgfx_view_id_t viewid = ctx->hemisphere.viewids.base;

	BGFX(set_texture)(0, ctx->hemisphere.firstPass.hemispheresTextureHandle, ctx->hemisphere.rbTexture[fbRead], UINT32_MAX);
	BGFX(set_texture)(1, ctx->hemisphere.firstPass.weightsTextureHandle, ctx->hemisphere.firstPass.weightsTexture, UINT32_MAX);

	BGFX(submit)(++viewid, ctx->hemisphere.firstPass.prog, 0, discardStates);

	while (outHemiSize > 1)
	{
		LM_SWAP(int, fbRead, fbWrite);
		outHemiSize /= 2;

		BGFX(set_state)(BGFX_STATE_DEPTH_TEST_NEVER|BGFX_STATE_WRITE_RGB|BGFX_STATE_WRITE_A, 0);
		BGFX(set_texture)(0, ctx->hemisphere.downsamplePass.hemispheresTextureHandle, ctx->hemisphere.rbTexture[fbRead], UINT32_MAX);
		BGFX(submit)(++viewid, ctx->hemisphere.downsamplePass.prog, 0, discardStates);
	}

	BGFX(blit)(ctx->hemisphere.storage_viewid,
		ctx->hemisphere.storage.texture, 0, ctx->hemisphere.storage.writePosition.x, ctx->hemisphere.storage.writePosition.y, 0, 
		ctx->hemisphere.rbTexture[fbWrite], 0, 0, 0, 0, ctx->hemisphere.fbHemiCountX, ctx->hemisphere.fbHemiCountY, 0);
	BGFX(frame)(false);
#else
	glDisable(GL_DEPTH_TEST);
	glBindVertexArray(ctx->hemisphere.vao);

	glBindFramebuffer(GL_FRAMEBUFFER, ctx->hemisphere.fb[fbWrite]);
	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, ctx->hemisphere.fbTexture[fbWrite], 0);
	glViewport(0, 0, outHemiSize * ctx->hemisphere.fbHemiCountX, outHemiSize * ctx->hemisphere.fbHemiCountY);
	glUseProgram(ctx->hemisphere.firstPass.programID);
	glUniform1i(ctx->hemisphere.firstPass.hemispheresTextureID, 0);
	glActiveTexture(GL_TEXTURE0);
	glBindTexture(GL_TEXTURE_2D, ctx->hemisphere.fbTexture[fbRead]);
	glUniform1i(ctx->hemisphere.firstPass.weightsTextureID, 1);
	glActiveTexture(GL_TEXTURE1);
	glBindTexture(GL_TEXTURE_2D, ctx->hemisphere.firstPass.weightsTexture);
	glActiveTexture(GL_TEXTURE0);
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	//glBindTexture(GL_TEXTURE_2D, 0);

#if 0
	// debug output
	int w = outHemiSize * ctx->hemisphere.fbHemiCountX, h = outHemiSize * ctx->hemisphere.fbHemiCountY;
	glBindBuffer(GL_PIXEL_PACK_BUFFER, 0);
	glBindFramebuffer(GL_READ_FRAMEBUFFER, ctx->hemisphere.fb[fbWrite]);
	glReadBuffer(GL_COLOR_ATTACHMENT0);
	float *image = new float[3 * w * h];
	glReadPixels(0, 0, w, h, GL_RGB, GL_FLOAT, image);
	lmImageSaveTGAf("firstpass.png", image, w, h, 3);
	delete[] image;
#endif

	// downsampling passes
	glUseProgram(ctx->hemisphere.downsamplePass.programID);
	glUniform1i(ctx->hemisphere.downsamplePass.hemispheresTextureID, 0);
	while (outHemiSize > 1)
	{
		LM_SWAP(int, fbRead, fbWrite);
		outHemiSize /= 2;
		glBindFramebuffer(GL_FRAMEBUFFER, ctx->hemisphere.fb[fbWrite]);
		glViewport(0, 0, outHemiSize * ctx->hemisphere.fbHemiCountX, outHemiSize * ctx->hemisphere.fbHemiCountY);
		glBindTexture(GL_TEXTURE_2D, ctx->hemisphere.fbTexture[fbRead]);
		glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
		//glBindTexture(GL_TEXTURE_2D, 0);
	}

	// copy results to storage texture
	glBindTexture(GL_TEXTURE_2D, ctx->hemisphere.storage.texture);
	glCopyTexSubImage2D(GL_TEXTURE_2D, 0,
		ctx->hemisphere.storage.writePosition.x, ctx->hemisphere.storage.writePosition.y,
		0, 0, ctx->hemisphere.fbHemiCountX, ctx->hemisphere.fbHemiCountY);
	glBindTexture(GL_TEXTURE_2D, 0);
	glBindFramebuffer(GL_FRAMEBUFFER, 0);
	glBindVertexArray(0);
	glEnable(GL_DEPTH_TEST);
#endif
}

static void lm_integrateHemisphereBatch(lm_context *ctx)
{
	if (!ctx->hemisphere.fbHemiIndex)
		return; // nothing to do

	lm_downsample(ctx);

	// copy position mapping to storage
	for (unsigned int y = 0; y < ctx->hemisphere.fbHemiCountY; y++)
	{
		int sy = ctx->hemisphere.storage.writePosition.y + y;
		for (unsigned int x = 0; x < ctx->hemisphere.fbHemiCountX; x++)
		{
			int sx = ctx->hemisphere.storage.writePosition.x + x;
			unsigned int hemiIndex = y * ctx->hemisphere.fbHemiCountX + x;
			if (hemiIndex >= ctx->hemisphere.fbHemiIndex)
				ctx->hemisphere.storage.toLightmapLocation[sy * ctx->lightmap.width + sx] = lm_i2(-1, -1);
			else
				ctx->hemisphere.storage.toLightmapLocation[sy * ctx->lightmap.width + sx] = ctx->hemisphere.fbHemiToLightmapLocation[hemiIndex];
		}
	}

	// advance storage texture write position
	ctx->hemisphere.storage.writePosition.x += ctx->hemisphere.fbHemiCountX;
	if (ctx->hemisphere.storage.writePosition.x + (int)ctx->hemisphere.fbHemiCountX > ctx->lightmap.width)
	{
		ctx->hemisphere.storage.writePosition.x = 0;
		ctx->hemisphere.storage.writePosition.y += ctx->hemisphere.fbHemiCountY;
		assert(ctx->hemisphere.storage.writePosition.y + (int)ctx->hemisphere.fbHemiCountY < ctx->lightmap.height);
	}

	ctx->hemisphere.fbHemiIndex = 0;
}

static void lm_getLightmapTextureData(lm_context *ctx, float *hemi)
{
#ifdef USE_BGFX
	uint32_t whichframe = BGFX(read_texture)(ctx->hemisphere.storage.texture, hemi, 0);
	while (BGFX(frame)(false) < whichframe);
#else
	glBindTexture(GL_TEXTURE_2D, ctx->hemisphere.storage.texture);
	glGetTexImage(GL_TEXTURE_2D, 0, GL_RGBA, GL_FLOAT, hemi);
#endif 
}

static void lm_writeResultsToLightmap(lm_context *ctx)
{
	// do the GPU->CPU transfer of downsampled hemispheres
	float *hemi = (float*)LM_CALLOC(ctx->lightmap.width * ctx->lightmap.height, 4 * sizeof(float));
	lm_getLightmapTextureData(ctx, hemi);

	// write results to lightmap texture
	for (int y = 0; y < ctx->hemisphere.storage.writePosition.y + (int)ctx->hemisphere.fbHemiCountY; y++)
	{
		for (int x = 0; x < ctx->lightmap.width; x++)
		{
			lm_ivec2 lmUV = ctx->hemisphere.storage.toLightmapLocation[y * ctx->lightmap.width + x];
			if (lmUV.x >= 0)
			{
				float *c = hemi + (y * ctx->lightmap.width + x) * 4;
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
			ctx->hemisphere.storage.toLightmapLocation[y * ctx->lightmap.width + x].x = -1; // reset
		}
	}

	LM_FREE(hemi);
	ctx->hemisphere.storage.writePosition = lm_i2(0, 0);
}

static void lm_setView(
	int* viewport, int x, int y, int w, int h,
	float* view,   lm_vec3 pos, lm_vec3 dir, lm_vec3 up,
	float* proj,   float l, float r, float b, float t, float n, float f)
{
	// viewport
	viewport[0] = x; viewport[1] = y; viewport[2] = w; viewport[3] = h;

	// view matrix: lookAt(pos, pos + dir, up)
	lm_vec3 side = lm_cross3(dir, up);
	//up = cross(side, dir);
	dir = lm_negate3(dir); pos = lm_negate3(pos);
	view[ 0] = side.x;             view[ 1] = up.x;             view[ 2] = dir.x;             view[ 3] = 0.0f;
	view[ 4] = side.y;             view[ 5] = up.y;             view[ 6] = dir.y;             view[ 7] = 0.0f;
	view[ 8] = side.z;             view[ 9] = up.z;             view[10] = dir.z;             view[11] = 0.0f;
	view[12] = lm_dot3(side, pos); view[13] = lm_dot3(up, pos); view[14] = lm_dot3(dir, pos); view[15] = 1.0f;

	// projection matrix: frustum(l, r, b, t, n, f)
	float ilr = 1.0f / (r - l), ibt = 1.0f / (t - b), ninf = -1.0f / (f - n), n2 = 2.0f * n;
	proj[ 0] = n2 * ilr;      proj[ 1] = 0.0f;          proj[ 2] = 0.0f;           proj[ 3] = 0.0f;
	proj[ 4] = 0.0f;          proj[ 5] = n2 * ibt;      proj[ 6] = 0.0f;           proj[ 7] = 0.0f;
	proj[ 8] = (r + l) * ilr; proj[ 9] = (t + b) * ibt; proj[10] = (f + n) * ninf; proj[11] = -1.0f;
	proj[12] = 0.0f;          proj[13] = 0.0f;          proj[14] = f * n2 * ninf;  proj[15] = 0.0f;
}

static void lm_initFrameBuffer(lm_context *ctx)
{
#ifdef USE_BGFX
	uint32_t color =(uint32_t)(ctx->hemisphere.clearColor.r * 255) << 0 |
					(uint32_t)(ctx->hemisphere.clearColor.g * 255) << 8 |
					(uint32_t)(ctx->hemisphere.clearColor.b * 255) << 16|
					(uint32_t)(0xff) << 24;
	if (ctx->hemisphere.fbHemiIndex == 0){
		BGFX(set_view_clear)(ctx->hemisphere.viewids.base, BGFX_CLEAR_COLOR|BGFX_CLEAR_DEPTH, color, 1.0f, 0);
	} else {
		BGFX(set_view_clear)(ctx->hemisphere.viewids.base, BGFX_CLEAR_NONE, color, 1.0f, 0);
	}
#else
	// prepare hemisphere
	glBindFramebuffer(GL_FRAMEBUFFER, ctx->hemisphere.fb[0]);
	if (ctx->hemisphere.fbHemiIndex == 0)
	{
		// prepare hemisphere batch
		glClearColor( // clear to valid background pixels!
			ctx->hemisphere.clearColor.r,
			ctx->hemisphere.clearColor.g,
			ctx->hemisphere.clearColor.b, 1.0f);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	}
#endif
}

// returns true if a hemisphere side was prepared for rendering and
// false if we finished the current hemisphere
static lm_bool lm_beginSampleHemisphere(lm_context *ctx, int* viewport, float* view, float* proj)
{
	if (ctx->meshPosition.hemisphere.side >= 5)
		return LM_FALSE;

	if (ctx->meshPosition.hemisphere.side == 0)
	{
		lm_initFrameBuffer(ctx);
		ctx->hemisphere.fbHemiToLightmapLocation[ctx->hemisphere.fbHemiIndex] =
			lm_i2(ctx->meshPosition.rasterizer.x, ctx->meshPosition.rasterizer.y);
	}

	// find the target position in the batch
	int x = (ctx->hemisphere.fbHemiIndex % ctx->hemisphere.fbHemiCountX) * ctx->hemisphere.size * 3;
	int y = (ctx->hemisphere.fbHemiIndex / ctx->hemisphere.fbHemiCountX) * ctx->hemisphere.size;

	int size = ctx->hemisphere.size;
	float zNear = ctx->hemisphere.zNear;
	float zFar = ctx->hemisphere.zFar;

	lm_vec3 pos = ctx->meshPosition.sample.position;
	lm_vec3 dir = ctx->meshPosition.sample.direction;
	lm_vec3 up = ctx->meshPosition.sample.up;
	lm_vec3 right = lm_cross3(dir, up);

	// find the view parameters of the hemisphere side that we will render next
	// hemisphere layout in the framebuffer:
	//       +-------+---+---+-------+
	//       |       |   |   |   D   |
	//       |   C   | R | L +-------+
	//       |       |   |   |   U   |
	//       +-------+---+---+-------+
	switch (ctx->meshPosition.hemisphere.side)
	{
	case 0: // center
		lm_setView(viewport, x, y, size, size,
				   view,     pos, dir, up,
				   proj,     -zNear, zNear, -zNear, zNear, zNear, zFar);
		break;
	case 1: // right
		lm_setView(viewport, size + x, y, size / 2, size,
				   view,     pos, right, up,
				   proj,     -zNear, 0.0f, -zNear, zNear, zNear, zFar);
		break;
	case 2: // left
		lm_setView(viewport, size + x + size / 2, y, size / 2, size,
				   view,     pos, lm_negate3(right), up,
				   proj,     0.0f, zNear, -zNear, zNear, zNear, zFar);
		break;
	case 3: // down
		lm_setView(viewport, 2 * size + x, y + size / 2, size, size / 2,
				   view,     pos, lm_negate3(up), dir,
				   proj,     -zNear, zNear, 0.0f, zNear, zNear, zFar);
		break;
	case 4: // up
		lm_setView(viewport, 2 * size + x, y, size, size / 2,
				   view,     pos, up, lm_negate3(dir),
				   proj,     -zNear, zNear, -zNear, 0.0f, zNear, zFar);
		break;
	default:
		assert(LM_FALSE);
		break;
	}

	return LM_TRUE;
}

static void lm_endFramebuffer(lm_context *ctx)
{
#ifndef USE_BGFX
	glBindFramebuffer(GL_FRAMEBUFFER, 0);
#endif 
}

static void lm_endSampleHemisphere(lm_context *ctx)
{
	if (++ctx->meshPosition.hemisphere.side == 5)
	{
		// finish hemisphere
		lm_endFramebuffer(ctx);
		if (++ctx->hemisphere.fbHemiIndex == ctx->hemisphere.fbHemiCountX * ctx->hemisphere.fbHemiCountY)
		{
			// downsample new hemisphere batch and store the results
			lm_integrateHemisphereBatch(ctx);
		}
	}
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

static void lm_setMeshPosition(lm_context *ctx, unsigned int indicesTriangleBaseIndex)
{
	// fetch triangle at the specified indicesTriangleBaseIndex
	ctx->meshPosition.triangle.baseIndex = indicesTriangleBaseIndex;

	// load and transform triangle to process next
	lm_vec2 uvMin = lm_v2(FLT_MAX, FLT_MAX), uvMax = lm_v2(-FLT_MAX, -FLT_MAX);
	lm_vec2 uvScale = lm_v2i(ctx->lightmap.width, ctx->lightmap.height);
	unsigned int vIndices[3];
	for (int i = 0; i < 3; i++)
	{
		// decode index
		unsigned int vIndex;
		switch (ctx->mesh.indicesType)
		{
		case LM_NONE:
			vIndex = ctx->meshPosition.triangle.baseIndex + i;
			break;
		case LM_UNSIGNED_BYTE:
			vIndex = ((const unsigned char*)ctx->mesh.indices + ctx->meshPosition.triangle.baseIndex)[i];
			break;
		case LM_UNSIGNED_SHORT:
			vIndex = ((const unsigned short*)ctx->mesh.indices + ctx->meshPosition.triangle.baseIndex)[i];
			break;
		case LM_UNSIGNED_INT:
			vIndex = ((const unsigned int*)ctx->mesh.indices + ctx->meshPosition.triangle.baseIndex)[i];
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
			const unsigned char *uc = (const unsigned char*)pPtr;
			p = lm_v3(uc[0], uc[1], uc[2]);
		} break;
		case LM_UNSIGNED_SHORT: {
			const unsigned short *us = (const unsigned short*)pPtr;
			p = lm_v3(us[0], us[1], us[2]);
		} break;
		case LM_UNSIGNED_INT: {
			const unsigned int *ui = (const unsigned int*)pPtr;
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
			const unsigned char *uc = (const unsigned char*)uvPtr;
			uv = lm_v2(uc[0] / (float)UCHAR_MAX, uc[1] / (float)UCHAR_MAX);
		} break;
		case LM_UNSIGNED_SHORT: {
			const unsigned short *us = (const unsigned short*)uvPtr;
			uv = lm_v2(us[0] / (float)USHRT_MAX, us[1] / (float)USHRT_MAX);
		} break;
		case LM_UNSIGNED_INT: {
			const unsigned int *ui = (const unsigned int*)uvPtr;
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
		lm_sub3(ctx->meshPosition.triangle.p[1], ctx->meshPosition.triangle.p[0]),
		lm_sub3(ctx->meshPosition.triangle.p[2], ctx->meshPosition.triangle.p[0]));

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

	// try moving to first valid sample position
	if (ctx->meshPosition.rasterizer.x <= ctx->meshPosition.rasterizer.maxx &&
		ctx->meshPosition.rasterizer.y <= ctx->meshPosition.rasterizer.maxy &&
		lm_findFirstConservativeTriangleRasterizerPosition(ctx))
		ctx->meshPosition.hemisphere.side = 0; // we can start sampling the hemisphere
	else
		ctx->meshPosition.hemisphere.side = 5; // no samples on this triangle! put hemisphere sampler into finished state
}

#ifndef USE_BGFX
static GLuint lm_LoadShader(GLenum type, const char *source)
{
	GLuint shader = glCreateShader(type);
	if (shader == 0)
	{
		fprintf(stderr, "Could not create shader!\n");
		return 0;
	}
	glShaderSource(shader, 1, &source, NULL);
	glCompileShader(shader);
	GLint compiled;
	glGetShaderiv(shader, GL_COMPILE_STATUS, &compiled);
	if (!compiled)
	{
		fprintf(stderr, "Could not compile shader!\n");
		GLint infoLen = 0;
		glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &infoLen);
		if (infoLen)
		{
			char* infoLog = (char*)malloc(infoLen);
			glGetShaderInfoLog(shader, infoLen, NULL, infoLog);
			fprintf(stderr, "%s\n", infoLog);
			free(infoLog);
		}
		glDeleteShader(shader);
		return 0;
	}
	return shader;
}

static GLuint lm_LoadProgram(const char *vp, const char *fp)
{
	GLuint program = glCreateProgram();
	if (program == 0)
	{
		fprintf(stderr, "Could not create program!\n");
		return 0;
	}
	GLuint vertexShader = lm_LoadShader(GL_VERTEX_SHADER, vp);
	GLuint fragmentShader = lm_LoadShader(GL_FRAGMENT_SHADER, fp);
	glAttachShader(program, vertexShader);
	glAttachShader(program, fragmentShader);
	glLinkProgram(program);
	glDeleteShader(vertexShader);
	glDeleteShader(fragmentShader);
	GLint linked;
	glGetProgramiv(program, GL_LINK_STATUS, &linked);
	if (!linked)
	{
		fprintf(stderr, "Could not link program!\n");
		GLint infoLen = 0;
		glGetProgramiv(program, GL_INFO_LOG_LENGTH, &infoLen);
		if (infoLen)
		{
			char* infoLog = (char*)malloc(sizeof(char) * infoLen);
			glGetProgramInfoLog(program, infoLen, NULL, infoLog);
			fprintf(stderr, "%s\n", infoLog);
			free(infoLog);
		}
		glDeleteProgram(program);
		return 0;
	}
	return program;
}
#endif 
static float lm_defaultWeights(float cos_theta, void *userdata)
{
	return 1.0f;
}

static void lm_initContext(lm_context *ctx, unsigned int w[2], unsigned int h[2])
{
#ifdef USE_BGFX
	uint64_t flags = BGFX_SAMPLER_U_CLAMP|BGFX_SAMPLER_V_CLAMP|BGFX_SAMPLER_MIN_POINT|BGFX_SAMPLER_MAG_POINT|BGFX_TEXTURE_RT;
	for (int i=0; i<2; ++i){
		ctx->hemisphere.rbTexture[i] = BGFX(create_texture_2d)(w[i], h[i], false, 1, BGFX_TEXTURE_FORMAT_RGBA32F, flags, NULL);
	}

	bgfx_vertex_layout_t layout;
	BGFX(vertex_layout_begin)(&layout, BGFX_RENDERER_TYPE_NOOP);
	BGFX(vertex_layout_skip)(&layout, 1);	//need > 0
	BGFX(vertex_layout_end)(&layout);

	BGFX(alloc_transient_vertex_buffer)(&ctx->hemisphere.tvb, 4, &layout);	//not fill tvb.data, shader use gl_VertexID, 4 for quad vertex index

	ctx->hemisphere.rbDepth = BGFX(create_texture_2d)(w[0], h[0], false, 1, BGFX_TEXTURE_FORMAT_D24, flags, NULL);

	bgfx_texture_handle_t handles[2] = {ctx->hemisphere.rbTexture[0], ctx->hemisphere.rbDepth};
	ctx->hemisphere.fb[0] = BGFX(create_frame_buffer_from_handles)(2, handles, false);
	handles[0] = ctx->hemisphere.rbTexture[1];
	ctx->hemisphere.fb[1] = BGFX(create_frame_buffer_from_handles)(1, handles, false);
#else
	glGenTextures(2, ctx->hemisphere.fbTexture);
	glGenFramebuffers(2, ctx->hemisphere.fb);
	glGenRenderbuffers(1, &ctx->hemisphere.fbDepth);

	glBindRenderbuffer(GL_RENDERBUFFER, ctx->hemisphere.fbDepth);
	glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, w[0], h[0]);
	glBindFramebuffer(GL_FRAMEBUFFER, ctx->hemisphere.fb[0]);
	glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, ctx->hemisphere.fbDepth);
	for (int i = 0; i < 2; i++)
	{
		glBindTexture(GL_TEXTURE_2D, ctx->hemisphere.fbTexture[i]);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA32F, w[i], h[i], 0, GL_RGBA, GL_FLOAT, 0);

		glBindFramebuffer(GL_FRAMEBUFFER, ctx->hemisphere.fb[i]);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, ctx->hemisphere.fbTexture[i], 0);
		GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
		if (status != GL_FRAMEBUFFER_COMPLETE)
		{
			fprintf(stderr, "Could not create framebuffer!\n");
			glDeleteRenderbuffers(1, &ctx->hemisphere.fbDepth);
			glDeleteFramebuffers(2, ctx->hemisphere.fb);
			glDeleteTextures(2, ctx->hemisphere.fbTexture);
			LM_FREE(ctx);
			return NULL;
		}
	}
	glBindFramebuffer(GL_FRAMEBUFFER, 0);

	// dummy vao for fullscreen quad rendering
	glGenVertexArrays(1, &ctx->hemisphere.vao);

	// hemisphere shader (weighted downsampling of the 3x1 hemisphere layout to a 0.5x0.5 square)
	{
		const char *vs =
			"#version 150 core\n"
			"const vec2 ps[4] = vec2[](vec2(1, -1), vec2(1, 1), vec2(-1, -1), vec2(-1, 1));\n"
			"void main()\n"
			"{\n"
				"gl_Position = vec4(ps[gl_VertexID], 0, 1);\n"
			"}\n";
		const char *fs =
			"#version 150 core\n"
			"uniform sampler2D hemispheres;\n"
			"uniform sampler2D weights;\n"

			"layout(pixel_center_integer) in vec4 gl_FragCoord;\n" // whole integer values represent pixel centers, GL_ARB_fragment_coord_conventions

			"out vec4 outColor;\n"

			"vec4 weightedSample(ivec2 h_uv, ivec2 w_uv, ivec2 quadrant)\n"
			"{\n"
				"vec4 sample = texelFetch(hemispheres, h_uv + quadrant, 0);\n"
				"vec2 weight = texelFetch(weights, w_uv + quadrant, 0).rg;\n"
				"return vec4(sample.rgb * weight.r, sample.a * weight.g);\n"
			"}\n"

			"vec4 threeWeightedSamples(ivec2 h_uv, ivec2 w_uv, ivec2 offset)\n"
			"{\n" // horizontal triple sum
				"vec4 sum = weightedSample(h_uv, w_uv, offset);\n"
				"sum += weightedSample(h_uv, w_uv, offset + ivec2(2, 0));\n"
				"sum += weightedSample(h_uv, w_uv, offset + ivec2(4, 0));\n"
				"return sum;\n"
			"}\n"

			"void main()\n"
			"{\n" // this is a weighted sum downsampling pass (alpha component contains the weighted valid sample count)
				"vec2 in_uv = gl_FragCoord.xy * vec2(6.0, 2.0) + vec2(0.5);\n"
				"ivec2 h_uv = ivec2(in_uv);\n"
				"ivec2 w_uv = ivec2(mod(in_uv, vec2(textureSize(weights, 0))));\n" // there's no integer modulo :(
				"vec4 lb = threeWeightedSamples(h_uv, w_uv, ivec2(0, 0));\n"
				"vec4 rb = threeWeightedSamples(h_uv, w_uv, ivec2(1, 0));\n"
				"vec4 lt = threeWeightedSamples(h_uv, w_uv, ivec2(0, 1));\n"
				"vec4 rt = threeWeightedSamples(h_uv, w_uv, ivec2(1, 1));\n"
				"outColor = lb + rb + lt + rt;\n"
			"}\n";
		ctx->hemisphere.firstPass.programID = lm_LoadProgram(vs, fs);
		if (!ctx->hemisphere.firstPass.programID)
		{
			fprintf(stderr, "Error loading the hemisphere first pass shader program... leaving!\n");
			glDeleteVertexArrays(1, &ctx->hemisphere.vao);
			glDeleteRenderbuffers(1, &ctx->hemisphere.fbDepth);
			glDeleteFramebuffers(2, ctx->hemisphere.fb);
			glDeleteTextures(2, ctx->hemisphere.fbTexture);
			LM_FREE(ctx);
			return NULL;
		}
		ctx->hemisphere.firstPass.hemispheresTextureID = glGetUniformLocation(ctx->hemisphere.firstPass.programID, "hemispheres");
		ctx->hemisphere.firstPass.weightsTextureID = glGetUniformLocation(ctx->hemisphere.firstPass.programID, "weights");
	}

	// downsample shader
	{
		const char *vs =
			"#version 150 core\n"
			"const vec2 ps[4] = vec2[](vec2(1, -1), vec2(1, 1), vec2(-1, -1), vec2(-1, 1));\n"
			"void main()\n"
			"{\n"
				"gl_Position = vec4(ps[gl_VertexID], 0, 1);\n"
			"}\n";
		const char *fs =
			"#version 150 core\n"
			"uniform sampler2D hemispheres;\n"

			"layout(pixel_center_integer) in vec4 gl_FragCoord;\n" // whole integer values represent pixel centers, GL_ARB_fragment_coord_conventions

			"out vec4 outColor;\n"

			"void main()\n"
			"{\n" // this is a sum downsampling pass (alpha component contains the weighted valid sample count)
				"ivec2 h_uv = ivec2(gl_FragCoord.xy) * 2;\n"
				"vec4 lb = texelFetch(hemispheres, h_uv + ivec2(0, 0), 0);\n"
				"vec4 rb = texelFetch(hemispheres, h_uv + ivec2(1, 0), 0);\n"
				"vec4 lt = texelFetch(hemispheres, h_uv + ivec2(0, 1), 0);\n"
				"vec4 rt = texelFetch(hemispheres, h_uv + ivec2(1, 1), 0);\n"
				"outColor = lb + rb + lt + rt;\n"
			"}\n";
		ctx->hemisphere.downsamplePass.programID = lm_LoadProgram(vs, fs);
		if (!ctx->hemisphere.downsamplePass.programID)
		{
			fprintf(stderr, "Error loading the hemisphere downsample pass shader program... leaving!\n");
			glDeleteProgram(ctx->hemisphere.firstPass.programID);
			glDeleteVertexArrays(1, &ctx->hemisphere.vao);
			glDeleteRenderbuffers(1, &ctx->hemisphere.fbDepth);
			glDeleteFramebuffers(2, ctx->hemisphere.fb);
			glDeleteTextures(2, ctx->hemisphere.fbTexture);
			LM_FREE(ctx);
			return NULL;
		}
		ctx->hemisphere.downsamplePass.hemispheresTextureID = glGetUniformLocation(ctx->hemisphere.downsamplePass.programID, "hemispheres");
	}

	// hemisphere weights texture
	glGenTextures(1, &ctx->hemisphere.firstPass.weightsTexture);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
#endif
}

lm_context *lmCreate(int hemisphereSize, float zNear, float zFar,
	float clearR, float clearG, float clearB,
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
	ctx->hemisphere.clearColor.r = clearR;
	ctx->hemisphere.clearColor.g = clearG;
	ctx->hemisphere.clearColor.b = clearB;

	// calculate hemisphere batch size
	ctx->hemisphere.fbHemiCountX = 1536 / (3 * ctx->hemisphere.size);
	ctx->hemisphere.fbHemiCountY = 512 / ctx->hemisphere.size;

	// hemisphere batch framebuffers
	unsigned int w[] = {
		ctx->hemisphere.fbHemiCountX * ctx->hemisphere.size * 3,
		ctx->hemisphere.fbHemiCountX * ctx->hemisphere.size / 2 };
	unsigned int h[] = {
		ctx->hemisphere.fbHemiCountY * ctx->hemisphere.size,
		ctx->hemisphere.fbHemiCountY * ctx->hemisphere.size / 2 };

	lm_initContext(ctx, w, h);
	lmSetHemisphereWeights(ctx, lm_defaultWeights, 0);

	// allocate batchPosition-to-lightmapPosition map
	ctx->hemisphere.fbHemiToLightmapLocation = (lm_ivec2*)LM_CALLOC(ctx->hemisphere.fbHemiCountX * ctx->hemisphere.fbHemiCountY, sizeof(lm_ivec2));
	return ctx;
}

static void lm_destroyGPUData(lm_context *ctx)
{
#ifdef USE_BGFX
	BGFX(destroy_texture)(ctx->hemisphere.rbTexture[0]);
	BGFX(destroy_texture)(ctx->hemisphere.rbTexture[1]);
	BGFX(destroy_texture)(ctx->hemisphere.rbDepth);

	BGFX(destroy_texture)(ctx->hemisphere.firstPass.weightsTexture);
	BGFX(destroy_texture)(ctx->hemisphere.storage.texture);

	BGFX(destroy_frame_buffer)(ctx->hemisphere.fb[0]);
	BGFX(destroy_frame_buffer)(ctx->hemisphere.fb[1]);

	BGFX(destroy_program)(ctx->hemisphere.firstPass.prog);
	BGFX(destroy_program)(ctx->hemisphere.downsamplePass.prog);
#else
	// reset state
	glUseProgram(0);
	glBindTexture(GL_TEXTURE_2D, 0);
	glBindBuffer(GL_PIXEL_PACK_BUFFER, 0);
	glBindVertexArray(0);
	glBindFramebuffer(GL_FRAMEBUFFER, 0);
	glBindFramebuffer(GL_READ_FRAMEBUFFER, 0);
	glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0);

	// delete gl objects
	glDeleteTextures(1, &ctx->hemisphere.firstPass.weightsTexture);
	glDeleteTextures(1, &ctx->hemisphere.storage.texture);
	glDeleteProgram(ctx->hemisphere.downsamplePass.programID);
	glDeleteProgram(ctx->hemisphere.firstPass.programID);
	glDeleteVertexArrays(1, &ctx->hemisphere.vao);
	glDeleteRenderbuffers(1, &ctx->hemisphere.fbDepth);
	glDeleteFramebuffers(2, ctx->hemisphere.fb);
	glDeleteTextures(2, ctx->hemisphere.fbTexture);
	glDeleteTextures(1, &ctx->hemisphere.storage.texture);

#endif
}

void lmDestroy(lm_context *ctx)
{
	lm_destroyGPUData(ctx);
	// free memory
	LM_FREE(ctx->hemisphere.storage.toLightmapLocation);
	LM_FREE(ctx->hemisphere.fbHemiToLightmapLocation);
#ifdef LM_DEBUG_INTERPOLATION
	LM_FREE(ctx->lightmap.debug);
#endif
	LM_FREE(ctx);
}

void lm_updateWeightTexture(lm_context *ctx, const float *weights)
{
#ifdef USE_BGFX
	const bgfx_memory_t *m = BGFX(copy)(weights, 3 * ctx->hemisphere.size * ctx->hemisphere.size * sizeof(float));
	BGFX(update_texture_2d)(ctx->hemisphere.firstPass.weightsTexture, 
		0, 0,	//layer, mipmap
		0, 0, 3 * ctx->hemisphere.size, ctx->hemisphere.size, //x, y, w, h
		m, 3 * ctx->hemisphere.size);
#else
	// upload weight texture
	glBindTexture(GL_TEXTURE_2D, ctx->hemisphere.firstPass.weightsTexture);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RG32F, 3 * ctx->hemisphere.size, ctx->hemisphere.size, 0, GL_RG, GL_FLOAT, weights);
#endif
}

void lmSetHemisphereWeights(lm_context *ctx, lm_weight_func f, void *userdata)
{
	// hemisphere weights texture. bakes in material dependent attenuation behaviour.
	float *weights = (float*)LM_CALLOC(2 * 3 * ctx->hemisphere.size * ctx->hemisphere.size, sizeof(float));
	float center = (ctx->hemisphere.size - 1) * 0.5f;
	double sum = 0.0;
	for (unsigned int y = 0; y < ctx->hemisphere.size; y++)
	{
		float dy = 2.0f * (y - center) / (float)ctx->hemisphere.size;
		for (unsigned int x = 0; x < ctx->hemisphere.size; x++)
		{
			float dx = 2.0f * (x - center) / (float)ctx->hemisphere.size;
			lm_vec3 v = lm_normalize3(lm_v3(dx, dy, 1.0f));

			float solidAngle = v.z * v.z * v.z;

			float *w0 = weights + 2 * (y * (3 * ctx->hemisphere.size) + x);
			float *w1 = w0 + 2 * ctx->hemisphere.size;
			float *w2 = w1 + 2 * ctx->hemisphere.size;

			// center weights
			w0[0] = solidAngle * f(v.z, userdata);
			w0[1] = solidAngle;

			// left/right side weights
			w1[0] = solidAngle * f(lm_absf(v.x), userdata);
			w1[1] = solidAngle;

			// up/down side weights
			w2[0] = solidAngle * f(lm_absf(v.y), userdata);
			w2[1] = solidAngle;

			sum += 3.0 * (double)solidAngle;
		}
	}

	// normalize weights
	float weightScale = (float)(1.0 / sum);
	for (unsigned int i = 0; i < 2 * 3 * ctx->hemisphere.size * ctx->hemisphere.size; i++)
		weights[i] *= weightScale;

	lm_updateWeightTexture(ctx, weights);
	LM_FREE(weights);
}

static void lm_checkSetTargetLightmap(lm_context *ctx, int w, int h)
{
#ifdef USE_BGFX
	uint64_t flags = BGFX_SAMPLER_U_CLAMP|BGFX_SAMPLER_V_CLAMP|BGFX_SAMPLER_MIN_POINT|BGFX_SAMPLER_MAG_POINT|
					BGFX_TEXTURE_BLIT_DST|BGFX_TEXTURE_READ_BACK;
	ctx->hemisphere.storage.texture = BGFX(create_texture_2d)(w, h, false, 1, BGFX_TEXTURE_FORMAT_RGBA32F, flags, NULL);
#else
	// allocate storage texture
	if (!ctx->hemisphere.storage.texture)
		glGenTextures(1, &ctx->hemisphere.storage.texture);
	glBindTexture(GL_TEXTURE_2D, ctx->hemisphere.storage.texture);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA32F, w, h, 0, GL_RGBA, GL_FLOAT, 0);
#endif
}

void lmSetTargetLightmap(lm_context *ctx, float *outLightmap, int w, int h, int c)
{
	ctx->lightmap.data = outLightmap;
	ctx->lightmap.width = w;
	ctx->lightmap.height = h;
	ctx->lightmap.channels = c;

	lm_checkSetTargetLightmap(ctx, w, h);
	// allocate storage position to lightmap position map
	if (ctx->hemisphere.storage.toLightmapLocation)
		LM_FREE(ctx->hemisphere.storage.toLightmapLocation);
	ctx->hemisphere.storage.toLightmapLocation = (lm_ivec2*)LM_CALLOC(w * h, sizeof(lm_ivec2));
	// invalidate all positions
	for (int i = 0; i < w * h; i++)
		ctx->hemisphere.storage.toLightmapLocation[i].x = -1;

#ifdef LM_DEBUG_INTERPOLATION
	if (ctx->lightmap.debug)
		LM_FREE(ctx->lightmap.debug);
	ctx->lightmap.debug = (unsigned char*)LM_CALLOC(ctx->lightmap.width * ctx->lightmap.height, 3);
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
	ctx->mesh.positions = (const unsigned char*)positionsXYZ;
	ctx->mesh.positionsType = positionsType;
	ctx->mesh.positionsStride = positionsStride == 0 ? sizeof(lm_vec3) : positionsStride;
	ctx->mesh.normals = (const unsigned char*)normalsXYZ;
	ctx->mesh.normalsType = normalsType;
	ctx->mesh.normalsStride = normalsStride == 0 ? sizeof(lm_vec3) : normalsStride;
	ctx->mesh.uvs = (const unsigned char*)lightmapCoordsUV;
	ctx->mesh.uvsType = lightmapCoordsType;
	ctx->mesh.uvsStride = lightmapCoordsStride == 0 ? sizeof(lm_vec2) : lightmapCoordsStride;
	ctx->mesh.indicesType = indicesType;
	ctx->mesh.indices = (const unsigned char*)indices;
	ctx->mesh.count = count;

	lm_inverseTranspose(transformationMatrix, ctx->mesh.normalMatrix);

	ctx->meshPosition.pass = 0;
	lm_setMeshPosition(ctx, 0);
}

#ifdef USE_BGFX
void lmSetDownsampleShaderingInfo(lm_context *ctx,
	bgfx_view_id_t viewid_base, uint16_t viewid_count, bgfx_view_id_t storage_viewid,
	bgfx_program_handle_t weightDownsampleProg, bgfx_uniform_handle_t weightHemisphereTextureHandle, bgfx_uniform_handle_t weightTextureHandle,
	bgfx_program_handle_t downsampleProg, bgfx_uniform_handle_t hemisphereTextureHanle)
{
	ctx->hemisphere.viewids.base = viewid_base;
	ctx->hemisphere.viewids.count = viewid_count;
	uint32_t hemisize = ctx->hemisphere.size;
	for (bgfx_view_id_t viewid=viewid_base; viewid < viewid_base+viewid_count-1; ++viewid){
		BGFX(set_view_mode)(viewid, BGFX_VIEW_MODE_SEQUENTIAL);
		int fbidx = (viewid-viewid_base) % 2;
		BGFX(set_view_frame_buffer)(viewid, ctx->hemisphere.fb[fbidx]);
		if (viewid != viewid_base){
			BGFX(set_view_rect)(viewid, 0, 0, hemisize*ctx->hemisphere.fbHemiCountX, hemisize*ctx->hemisphere.fbHemiCountY);
		}
		hemisize /= 2;
	}

	ctx->hemisphere.firstPass.prog						= weightDownsampleProg;
	ctx->hemisphere.firstPass.hemispheresTextureHandle 	= weightHemisphereTextureHandle;
	ctx->hemisphere.firstPass.weightsTextureHandle 		= weightTextureHandle;

	ctx->hemisphere.downsamplePass.prog 				= downsampleProg;
	ctx->hemisphere.downsamplePass.hemispheresTextureHandle = hemisphereTextureHanle;

	ctx->hemisphere.storage_viewid = storage_viewid;
}
#endif

lm_bool lmBegin(lm_context *ctx, int* outViewport4, float* outView4x4, float* outProjection4x4)
{
	assert(ctx->meshPosition.triangle.baseIndex < ctx->mesh.count);
	while (!lm_beginSampleHemisphere(ctx, outViewport4, outView4x4, outProjection4x4))
	{ // as long as there are no hemisphere sides to render...
		// try moving to the next rasterizer position
		if (lm_findNextConservativeTriangleRasterizerPosition(ctx))
		{ // if we successfully moved to the next sample position on the current triangle...
			ctx->meshPosition.hemisphere.side = 0; // start sampling a hemisphere there
		}
		else
		{ // if there are no valid sample positions on the current triangle...
			if (ctx->meshPosition.triangle.baseIndex + 3 < ctx->mesh.count)
			{ // ...and there are triangles left: move to the next triangle and continue sampling.
				lm_setMeshPosition(ctx, ctx->meshPosition.triangle.baseIndex + 3);
			}
			else
			{ // ...and there are no triangles left: finish
				lm_integrateHemisphereBatch(ctx); // integrate and store last batch
				lm_writeResultsToLightmap(ctx); // read storage data from gpu memory and write it to the lightmap

				if (++ctx->meshPosition.pass == ctx->meshPosition.passCount)
				{
					ctx->meshPosition.pass = 0;
					ctx->meshPosition.triangle.baseIndex = ctx->mesh.count; // set end condition (in case someone accidentally calls lmBegin again)

#ifdef LM_DEBUG_INTERPOLATION
					lmImageSaveTGAub("debug_interpolation.tga", ctx->lightmap.debug, ctx->lightmap.width, ctx->lightmap.height, 3);

					// lightmap texel statistics
					int rendered = 0, interpolated = 0, wasted = 0;
					for (int y = 0; y < ctx->lightmap.height; y++)
					{
						for (int x = 0; x < ctx->lightmap.width; x++)
						{
							if (ctx->lightmap.debug[(y * ctx->lightmap.width + x) * 3 + 0])
								rendered++;
							else if (ctx->lightmap.debug[(y * ctx->lightmap.width + x) * 3 + 1])
								interpolated++;
							else
								wasted++;
						}
					}
					int used = rendered + interpolated;
					int total = used + wasted;
					printf("\n#######################################################################\n");
					printf("%10d %6.2f%% rendered hemicubes integrated to lightmap texels.\n", rendered, 100.0f * (float)rendered / (float)total);
					printf("%10d %6.2f%% interpolated lightmap texels.\n", interpolated, 100.0f * (float)interpolated / (float)total);
					printf("%10d %6.2f%% wasted lightmap texels.\n", wasted, 100.0f * (float)wasted / (float)total);
					printf("\n%17.2f%% of used texels were rendered.\n", 100.0f * (float)rendered / (float)used);
					printf("#######################################################################\n");
#endif

					return LM_FALSE;
				}

				lm_setMeshPosition(ctx, 0); // start over with the next pass
			}
		}
	}
	return LM_TRUE;
}

float lmProgress(lm_context *ctx)
{
	float passProgress = (float)ctx->meshPosition.triangle.baseIndex / (float)ctx->mesh.count;
	return ((float)ctx->meshPosition.pass + passProgress) / (float)ctx->meshPosition.passCount;
}

void lmEnd(lm_context *ctx)
{
	lm_endSampleHemisphere(ctx);
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

void lmImageFtoUB(const float *image, unsigned char *outImage, int w, int h, int c, float max)
{
	assert(c > 0);
	float scale = 255.0f / (max != 0.0f ? max : lmImageMax(image, w, h, c, LM_ALL_CHANNELS));
	for (int i = 0; i < w * h * c; i++)
		outImage[i] = (unsigned char)lm_minf(lm_maxf(image[i] * scale, 0.0f), 255.0f);
}

// TGA output helpers
static void lm_swapRandBub(unsigned char *image, int w, int h, int c)
{
	assert(c >= 3);
	for (int i = 0; i < w * h * c; i += c)
		LM_SWAP(unsigned char, image[i], image[i + 2]);
}

lm_bool lmImageSaveTGAub(const char *filename, const unsigned char *image, int w, int h, int c)
{
	assert(c == 1 || c == 3 || c == 4);
	lm_bool isGreyscale = c == 1;
	lm_bool hasAlpha = c == 4;
	unsigned char header[18] = {
		0, 0, (unsigned char)(isGreyscale ? 3 : 2), 0, 0, 0, 0, 0, 0, 0, 0, 0,
		(unsigned char)(w & 0xff), (unsigned char)((w >> 8) & 0xff), (unsigned char)(h & 0xff), (unsigned char)((h >> 8) & 0xff),
		(unsigned char)(8 * c), (unsigned char)(hasAlpha ? 8 : 0)
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
		lm_swapRandBub((unsigned char*)image, w, h, c);
	fwrite(image, 1, w * h * c , file);
	if (!isGreyscale)
		lm_swapRandBub((unsigned char*)image, w, h, c);

	fclose(file);
	return LM_TRUE;
}

lm_bool lmImageSaveTGAf(const char *filename, const float *image, int w, int h, int c, float max)
{
	unsigned char *temp = (unsigned char*)LM_CALLOC(w * h * c, sizeof(unsigned char));
	lmImageFtoUB(image, temp, w, h, c, max);
	lm_bool success = lmImageSaveTGAub(filename, temp, w, h, c);
	LM_FREE(temp);
	return success;
}

#endif // LIGHTMAPPER_IMPLEMENTATION
