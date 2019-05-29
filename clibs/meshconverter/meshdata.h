#pragma once

#include "meshbase/meshbase.h"
#include "common.h"

#include <glm/vec4.hpp>
#include <glm/vec3.hpp>
#include <glm/mat4x4.hpp>

#include <vector>
#include <map>
#include <memory>
#include <string>

using LayoutArray = std::vector<std::string>;

struct load_config {
	load_config()
		: flags(0) {}

	bool NeedCreateNormal() const {
		return flags & CreateNormal;
	}

	bool NeedCreateTangentSpaceData() const {
		return flags & (CreateTangent | CreateBitangent);
	}

	bool NeedFlipU()const {
		return flags & FlipU;
	}

	bool NeedFlipV() const {
		return flags & FlipV;
	}

	bool NeedResetRootPosition() const {
		return flags & ResetRootPos;
	}


	bool IsLoadSkeleton() const {
		return flags & LoadSkeleton;
	}

	bool IsUsingCPUSkinning() const {
		return flags & UsingCPUSkinning;
	}

	LayoutArray layouts;

	enum {
		CreateNormal	= 0x00000001,
		CreateTangent	= 0x00000002,
		CreateBitangent = 0x00000004,

		InvertNormal	= 0x00000010,
		FlipU			= 0x00000020,
		FlipV			= 0x00000040,
		IndexBuffer32Bit= 0x00000080,
		ResetRootPos	= 0x00000100,

		AnimationMask	= 0xffff0000,
		LoadSkeleton	= 0x00010000,
		UsingCPUSkinning= 0x00020000,
	};
	uint32_t flags;
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

using buffer_ptr = std::unique_ptr<uint8_t[]>;

inline buffer_ptr make_buffer_ptr(size_t sizeInBytes) {
	return std::make_unique<uint8_t[]>(sizeInBytes);
}

struct vb_info {	
	size_t num_vertices;
	std::map<std::string, buffer_ptr>	vbraws;

	vb_info()
		: num_vertices(0)
	{}

	vb_info(vb_info &&other) 
		: num_vertices(other.num_vertices)
		, vbraws(std::move(other.vbraws))		
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