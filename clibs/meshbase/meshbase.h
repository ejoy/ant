#include <glm/vec4.hpp>
#include <glm/vec3.hpp>
#include <glm/mat4x4.hpp>
#include <glm/gtc/quaternion.hpp>

#include <limits>

#if defined(_MSC_VER)
	//  Microsoft 
#define MESHBASE_EXPORT __declspec(dllexport)
#define MESHBASE_IMPORT __declspec(dllimport)
#elif defined(__GNUC__)
	//  GCC
//#define EXPORT	__attribute__(visibility("default"))
	// need force export, visibility("default") will follow static lib setting
#define MESHBASE_EXPORT	__attribute__((dllexport))
#define MESHBASE_IMPORT
#else
	//  do nothing and hope for the best?
#define MESHBASE_EXPORT
#define MESHBASE_IMPORT
#pragma warning Unknown dynamic link import/export semantics.
#endif

inline constexpr glm::vec3 minvalue(){
	return glm::vec3(std::numeric_limits<float>::lowest());
}

inline constexpr glm::vec3 maxvalue(){
	return glm::vec3(std::numeric_limits<float>::max());
}

struct AABB {
	glm::vec3 min, max;

	AABB()
		: min(maxvalue())
		, max(minvalue())
	{}

	AABB(const glm::vec3 &_min, const glm::vec3 &_max) 
		: min(_min)
		, max(_max)
	{}

	bool IsValid() const {
		return min.x < max.x && min.y < max.y && min.z < max.z;		
	}

	void Init(const glm::vec3 *vertiecs, uint32_t num) {
		min = maxvalue();
		max = minvalue();

		for (uint32_t ii = 0; ii < num; ++ii) {
			const glm::vec3 &v = vertiecs[ii];
			Append(v);
		}
	}

	void Append(const glm::vec3 &v) {
		min.x = glm::min(min.x, v.x);
		max.x = glm::max(max.x, v.x);

		min.y = glm::min(min.y, v.y);
		max.y = glm::max(max.y, v.y);

		min.z = glm::min(min.z, v.z);
		max.z = glm::max(max.z, v.z);
	}

	void Transform(const glm::mat4x4 &trans) {
		glm::vec3 tmin = trans * glm::vec4(min, 0);
		glm::vec3 tmax = trans * glm::vec4(max, 0);

		min.x = glm::min(tmin.x, tmax.x);
		min.y = glm::min(tmin.y, tmax.y);
		min.z = glm::min(tmin.z, tmax.z);

		max.x = glm::max(tmin.x, tmax.x);
		max.y = glm::max(tmin.y, tmax.y);
		max.z = glm::max(tmin.z, tmax.z);
	}


	void Merge(const AABB &other) {
		min.x = glm::min(min.x, other.min.x);
		min.y = glm::min(min.y, other.min.y);
		min.z = glm::min(min.z, other.min.z);

		max.x = glm::max(max.x, other.max.x);
		max.y = glm::max(max.y, other.max.y);
		max.z = glm::max(max.z, other.max.z);
	}

	glm::vec3 Center() const {
		return (min + max) * 0.5f;
	}

	float DiagonalLength() const {
		return glm::length(max - min);
	}

	void Reset() {
		min = maxvalue();
		max = minvalue();
	}
};

struct BoundingSphere {
	glm::vec3 center;
	float radius;

	void Init(const AABB &aabb) {		
		center = aabb.Center();
		radius = aabb.DiagonalLength() * 0.5f;
	}

	void Reset() {
		center = glm::vec3(0.f);
		radius = 0.f;
	}
};

struct OBB {
	glm::mat4x4 m;
	void Init(const AABB & aabb) {
		m = glm::mat4x4(1.0f);
		auto &trans = m[3];
		const auto &c = aabb.Center();
		trans[0] = c[0], trans[1] = c[1], trans[2] = c[2], trans[3] = 1;

		glm::vec3 scale = aabb.max - aabb.min;			
		m[0][0] = scale[0];
		m[1][1] = scale[1];
		m[2][2] = scale[2];
	}

	void Reset() {
		m = glm::mat4x4(1.f);
	}
};

struct Bounding {
	AABB aabb;
	BoundingSphere sphere;
	OBB obb;
	void Init(const glm::vec3 *v, uint32_t num) {
		aabb.Init(v, num);
		sphere.Init(aabb);
		obb.Init(aabb);
	}

	void Merge(const Bounding &other) {
		aabb.Merge(other.aabb);
		sphere.Init(aabb);
		obb.Init(aabb);
	}

	void Reset() {
		aabb.Reset();
		sphere.Reset();
		obb.Reset();
	}
};