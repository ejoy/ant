#pragma once

#include <glm/vec4.hpp>
#include <glm/vec3.hpp>
#include <glm/mat4x4.hpp>

#include <vector>
#include <map>
#include <memory>

struct load_config {
	load_config()
		: layout("p3|n|T|b|t20|c30")
		, flags(0) {}

	bool NeedCreateNormal() const {
		return flags & CreateNormal;
	}

	bool NeedCreateTangentSpaceData() const {
		return flags & (CreateTangent | CreateBitangent);
	}

	bool NeedFlipUV()const {
		return flags & FlipUV;
	}

	bool NeedPackAsSOA() const {
		return flags & PackAsSOA;
	}

	bool IsLoadSkeleton() const {
		return flags & LoadSkeleton;
	}

	bool IsUsingCPUSkinning() const {
		return flags & UsingCPUSkinning;
	}

	std::string layout;

	enum {
		CreateNormal	= 0x00000001,
		CreateTangent	= 0x00000002,
		CreateBitangent = 0x00000004,

		InvertNormal	= 0x00000010,
		FlipUV			= 0x00000020,
		IndexBuffer32Bit= 0x00000040,
		PackAsSOA		= 0x00000080,

		AnimationMask	= 0xffff0000,
		LoadSkeleton	= 0x00010000,
		UsingCPUSkinning= 0x00020000,
	};
	uint32_t flags;
};

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

struct rawbuffer {
	uint8_t *data;
	size_t size;
	rawbuffer()
		: data(nullptr)
		, size(0)
	{}

	rawbuffer(size_t s)
		: data(new uint8_t[s])
		, size(s)
	{}

	explicit rawbuffer(rawbuffer &&tmp)
		: data(tmp.data)
		, size(tmp.size)
	{
		tmp.data = nullptr;
		tmp.size = 0;
	}

	rawbuffer& operator=(rawbuffer &&tmp) {
		if (data) {
			delete[] data;
			data = nullptr;
		}

		data = tmp.data;
		size = tmp.size;

		tmp.data = nullptr;
		tmp.size = 0;
		return *this;

	}

	~rawbuffer() {
		if (data) {
			delete[]data;
			data = nullptr;
		}
	}

private:
	rawbuffer(const rawbuffer &) = delete;
	rawbuffer operator=( const rawbuffer &) = delete;
};

struct vb_info {
	std::string layout;
	size_t num_vertices;

	std::map<std::string, rawbuffer>	vbraws;
	bool soa;

	vb_info()
		: num_vertices(0)		
		, soa(false)
	{}

	vb_info(vb_info &&other) 
		: layout(std::move(other.layout))		
		, num_vertices(other.num_vertices)
		, vbraws(std::move(other.vbraws))
		, soa(other.soa)
	{}
};

struct ib_info {
	uint8_t	format;
	size_t num_indices;
	uint8_t* ibraw;

	ib_info() 
		: format(0)
		, num_indices(0)
		, ibraw(nullptr)
	{}

	ib_info(ib_info &&other) 
		: format(other.format)
		, num_indices(other.num_indices)
		, ibraw(other.ibraw)
	{
		other.ibraw = nullptr;
		other.num_indices = 0;
		other.format = 0;
	}

	~ib_info() {
		if (ibraw) {
			delete[] ibraw;
			ibraw = nullptr;
		}
	}
};

#define MESH_DATA_MINOR_VERSION 0
#define MESH_DATA_MAJOR_VERSION	1
#define MESH_DATA_VERSION ((MESH_DATA_MAJOR_VERSION) << 16 | (MESH_DATA_MINOR_VERSION))
struct mesh_data {		
	std::vector<mesh_material_data> materials;
	struct group {
		group() 			
		{}

		group(group &&tmp) 
			: bounding(tmp.bounding)
			, name(std::move(tmp.name))
			, vb(std::move(tmp.vb))
			, ib(std::move(tmp.ib))			
			, primitives(std::move(tmp.primitives))
		{}

		~group() = default;

		Bounding bounding;
		std::string name;

		vb_info vb;
		ib_info ib;

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

	bool				usingCPUSkinning;
};

bool
WriteMeshData(const mesh_data &md, const std::string &srcfile, const std::string &outputfile);