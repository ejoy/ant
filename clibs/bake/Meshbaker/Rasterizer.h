#pragma once

#include "glm/glm.hpp"
#include <vector>

struct Rasterizer
{
	uint16_t minx, miny;
	uint16_t maxx, maxy;
	uint16_t x, y;
};

enum lm_type{
	LM_NONE = 0,
	LM_UNSIGNED_BYTE,
	LM_UNSIGNED_SHORT,
	LM_UNSIGNED_INT,
	LM_FLOAT,
};

struct Buffer {
	const uint8_t *data;
	lm_type type;
	uint32_t stride;
};

struct Mesh
{
	const float *modelMatrix;
	float normalMatrix[9];

	Buffer positions;
	Buffer normals;
	Buffer tangents;
	Buffer bitangents;
	Buffer uvs;
	Buffer indices;

	uint32_t count;
};

struct Triangle
{
	uint32_t baseIndex;
	glm::vec3 p[3];
	glm::vec3 n[3];
	glm::vec3 t[3];
	glm::vec3 b[3];
	glm::vec2 uv[3];
};

struct Sample
{
	glm::vec3 position;
	glm::vec3 direction;
	glm::vec3 tangent;
	glm::vec3 bitangent;
	glm::vec3 up;
};

struct SamplePosition{
	uint16_t rx, ry;
	Sample	sample;
};


void RasterMesh();