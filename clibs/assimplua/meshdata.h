#pragma once

#include <glm/vec4.hpp>
#include <glm/vec3.hpp>
#include <glm/mat4x4.hpp>

#include <vector>
#include <map>

struct AABB {
	glm::vec3 min, max;

	AABB()
		: min(10e10f, 10e10f, 10e10f)
		, max(-10e10f, -10e10f, -10e10f)
	{}

	bool IsValid() const {
		return min != glm::vec3(10e10f, 10e10f, 10e10f)
			&& max != glm::vec3(-10e10f, -10e10f, -10e10f);
	}

	void Init(const glm::vec3 *vertiecs, uint32_t num) {
		min = glm::vec3(10e10f, 10e10f, 10e10f);
		max = glm::vec3(-10e10f, -10e10f, -10e10f);

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
};

struct BoundingSphere {
	glm::vec3 center;
	float radius;

	void Init(const AABB &bb) {
		glm::vec3 delta = bb.max - bb.min;
		center = bb.min + delta * 0.5f;
		radius = glm::length(delta);
	}
};

struct Bounding {
	AABB aabb;
	BoundingSphere sphere;
	void Init(const glm::vec3 *v, uint32_t num) {
		aabb.Init(v, num);
		sphere.Init(aabb);
	}

	void Merge(const Bounding &other) {
		aabb.Merge(other.aabb);
		sphere.Init(aabb);
	}
};

struct mesh_material_data {
	std::string	name;
	std::map<std::string, std::string> textures;	// need an ordered map
	std::map<std::string, glm::vec3>	colors;		// need an ordered map
};

struct mesh_data {		
	std::vector<mesh_material_data> materials;
	struct group {
		group() 
			: vbraw(nullptr)
			, num_vertices(0)
			, ibraw(nullptr)
			, num_indices(0)
			, ib_format(0)
		{}

		group(group &&tmp) {
			ibraw = tmp.ibraw;
			num_indices = tmp.num_indices;

			vbraw = tmp.vbraw;
			num_vertices = tmp.num_vertices;
	
			name = std::move(tmp.name);
			vb_layout = std::move(tmp.vb_layout);

			primitives = std::move(tmp.primitives);
			
			tmp.ibraw = nullptr;
			tmp.vbraw = nullptr;
		}
		~group() {
			if (vbraw){ 
				delete[] vbraw;
				vbraw = nullptr;
			}

			if (ibraw) {
				delete[] ibraw;
				ibraw = nullptr;
			}
		}
		Bounding bounding;
		std::string name;

		std::string vb_layout;
		size_t num_vertices;
		uint8_t* vbraw;
		
		uint8_t	ib_format;
		size_t num_indices;
		uint8_t* ibraw;
		
		struct primitive_info {
			primitive_info() 
				: material_idx(-1)
				, start_vertex(0)
				, num_vertices(0)
				, start_index(0)
				, num_indices(0)
			{}

			Bounding bounding;

			glm::mat4x4 transform;
			std::string name;
			uint32_t material_idx;

			size_t start_vertex;
			size_t num_vertices;

			size_t start_index;
			size_t num_indices;			
		};

		std::vector<primitive_info>	primitives;
	};

	std::vector<group>	groups;
	Bounding			bounding;
};
