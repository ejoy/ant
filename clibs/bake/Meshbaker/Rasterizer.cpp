#include "Rasterizer.h"

#include "glm/glm.hpp"

#include <vector>
#include <set>

static lm_bool lm_hasConservativeTriangleRasterizerFinished(const Rasterizer &rasterizer)
{
	return rasterizer.y >= rasterizer.maxy;
}

static void lm_moveToNextPotentialConservativeTriangleRasterizerPosition(Rasterizer &rasterizer)
{
	++rasterizer.x;
	while (rasterizer.x >= rasterizer.maxx)
	{
		rasterizer.x = meshPosition.rasterizer.minx;
		++rasterizer.y;
		if (lm_hasConservativeTriangleRasterizerFinished(rasterizer))
			break;
	}
}

static lm_bool lm_isRasterizerPositionValid(const Rasterizer &meshPosition)
{
	return	rasterizer.x <= rasterizer.maxx &&
			rasterizer.y <= rasterizer.maxy;
}

static void lm_initMeshRasterizerPosition(uint16_t lmwidth, uint16_t lmheight, 
    const Mesh &mesh, Triangle &triangle, Rasterizer &rasterizer)
{
	// load and transform triangle to process next
	lm_vec2 uvMin = lm_v2(FLT_MAX, FLT_MAX), uvMax = lm_v2(-FLT_MAX, -FLT_MAX);
	lm_vec2 uvScale = {lmwidth, lmheight};

    const auto &normals = mesh.normals;
    const auto &tangents = mesh.tangents;
    const auto &bitangents = mesh.bitangents;
    const auto &uvs = mesh.uvs;
    const auto &indices = mesh.indices;

	uint32_t vIndices[3];
	for (int i = 0; i < 3; i++)
	{
        
		// decode index
		uint32_t vIndex;
		switch (indices.type)
		{
		case LM_NONE:
			vIndex = triangle.baseIndex + i;
			break;
		case LM_UNSIGNED_BYTE:
			vIndex = ((const uint8_t*)indices.data + triangle.baseIndex)[i];
			break;
		case LM_UNSIGNED_SHORT:
			vIndex = ((const unsigned short*)indices.data + triangle.baseIndex)[i];
			break;
		case LM_UNSIGNED_INT:
			vIndex = ((const uint32_t*)indices.data + triangle.baseIndex)[i];
			break;
		default:
			assert(LM_FALSE);
			break;
		}
		vIndices[i] = vIndex;

		// decode and pre-transform vertex position
        const auto &positions = mesh.positions;
		const void *pPtr = positions.data + vIndex * mesh.positions.stride;
		lm_vec3 p;
		switch (positions.type)
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
		triangle.p[i] = lm_transformPosition(mesh.modelMatrix, p);

		// decode and scale (to lightmap resolution) vertex lightmap texture coords
		const void *uvPtr = uvs.data + vIndex * uvs.stride;
		lm_vec2 uv;
		switch (uvs.type)
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

		triangle.uv[i] = lm_mul2(lm_pmod2(uv, 1.0f), uvScale); // maybe clamp to 0.0-1.0 instead of pmod?

		// decode and pre-transform vertex normal
		const void *nPtr = normals.data + vIndices[i] * normals.stride;
		lm_vec3 n;
		switch (normals.type)
		{
		// TODO: signed formats
		case LM_FLOAT: {
			n = *(const lm_vec3*)nPtr;
		} break;
		default: {
			assert(LM_FALSE);
		} break;
		}
		triangle.n[i] = lm_normalize3(lm_transformNormal(mesh.normalMatrix, n));

		const void *tPtr = tangents.data + vIndices[i] * tangents.stride;
		lm_vec3 t;
		switch (tangents.type)
		{
		// TODO: signed formats
		case LM_FLOAT: {
			t = *(const lm_vec3*)nPtr;
		} break;
		default: {
			assert(LM_FALSE);
		} break;
		}
		triangle.t[i] = lm_normalize3(lm_transformNormal(mesh.normalMatrix, t));

        const void *bPtr = bitangents.data + vIndices[i] * bitangents.stride;
		lm_vec3 b;
		switch (bitangents.type)
		{
		// TODO: signed formats
		case LM_FLOAT: {
			b = *(const lm_vec3*)bPtr;
		} break;
		default: {
			assert(LM_FALSE);
		} break;
		}
		triangle.b[i] = lm_normalize3(lm_transformNormal(mesh.normalMatrix, b));

        		// update bounds on lightmap
		uvMin = lm_min2(uvMin, triangle.uv[i]);
		uvMax = lm_max2(uvMax, triangle.uv[i]);
	}



	// calculate area of interest (on lightmap) for conservative rasterization
	lm_vec2 bbMin = lm_floor2(uvMin);
	lm_vec2 bbMax = lm_ceil2 (uvMax);
	rasterizer.minx = lm_maxi((int)bbMin.x - 1, 0);
	rasterizer.miny = lm_maxi((int)bbMin.y - 1, 0);
	rasterizer.maxx = lm_mini((int)bbMax.x + 1, lmwidth - 1);
	rasterizer.maxy = lm_mini((int)bbMax.y + 1, lmheight - 1);
	assert(rasterizer.minx <= rasterizer.maxx &&
		   rasterizer.miny <= rasterizer.maxy);
	rasterizer.x = rasterizer.minx;
	rasterizer.y = rasterizer.miny;

	if (!lm_isRasterizerPositionValid(rasterizer))
	{
		lm_moveToNextPotentialConservativeTriangleRasterizerPosition(rasterizer);
	}
}

void RasterMesh(uint16_t lmwidth, uint16_t lmheight, const Mesh &mesh,
std::vector<Triangle> &triangles)
{
	std::set<uint32_t>	duplicate_test;
	auto &samples = ctx->samples;

	const uint32_t maxsample = ctx->lightmap.width * ctx->lightmap.height;
	samples.reserve(maxsample);

	for (auto &t : triangles)
	{
		for(lm_initMeshRasterizerPosition(ctx);
			!lm_hasConservativeTriangleRasterizerFinished(ctx->meshPosition);
			lm_moveToNextPotentialConservativeTriangleRasterizerPosition(ctx->meshPosition))
		{
			if (!lm_trySamplingConservativeTriangleRasterizerPosition(
				ctx->meshPosition,
				ctx->lightmap, ctx->hemisphere,
				ctx->interpolationThreshold))
				continue;

			RasterizerPosition pos = {ctx->meshPosition.rasterizer.x, ctx->meshPosition.rasterizer.y};
			auto itfound = duplicate_test.find(pos.hashidx);
			if (itfound == duplicate_test.end()){
				duplicate_test.insert(pos.hashidx);
				SamplePosition s = {ctx->meshPosition.sample, pos};
				samples.push_back(s);
			}
		}
	}
}
