#include "meshdata.h"
#include "utils.h"

extern "C" {
#include <lua.h>  
#include <lualib.h>
#include <lauxlib.h>
}

// ozz
#include "ozz-animation/samples/framework/mesh.h"
#include "ozz-animation/samples/framework/utils.h"


static Bounding calc_bounding(ozz::sample::Mesh::Part &part) {
	Bounding bounding;

	if (!part.positions.empty()) {
		auto numVertices = part.vertex_count();
		for (auto iV = 0; iV < numVertices; ++iV) {
			glm::vec3 * p = (glm::vec3 *)(ozz::array_begin(part.positions) + iV * ozz::sample::Mesh::Part::kPositionsCpnts);
			bounding.aabb.Append(*p);
		}

		bounding.sphere.Init(bounding.aabb);
	}

	return bounding;
}

static bgfx::VertexDecl get_decl(const ozz::sample::Mesh &mesh) {
	bgfx::VertexDecl decl;
	if (!mesh.parts.empty()) {
		auto &part = mesh.parts.back();

		decl.begin();

		if (!part.positions.empty()) {
			decl.add(bgfx::Attrib::Position, ozz::sample::Mesh::Part::kPositionsCpnts, bgfx::AttribType::Float);
		}
		
		if (!part.normals.empty()) {
			decl.add(bgfx::Attrib::Normal, ozz::sample::Mesh::Part::kNormalsCpnts, bgfx::AttribType::Float, true);
		}

		if (!part.tangents.empty()) {
			decl.add(bgfx::Attrib::Tangent, ozz::sample::Mesh::Part::kTangentsCpnts, bgfx::AttribType::Float, true);
		}

		if (!part.colors.empty()) {
			decl.add(bgfx::Attrib::Color0, ozz::sample::Mesh::Part::kColorsCpnts, bgfx::AttribType::Uint8, true, true);
		}

		if (!part.uvs.empty()) {
			decl.add(bgfx::Attrib::TexCoord0, ozz::sample::Mesh::Part::kUVsCpnts, bgfx::AttribType::Float);
		}

		auto influences_count = part.influences_count();
		if (influences_count > 0) {
			assert(!part.joint_indices.empty());
			decl.add(bgfx::Attrib::Indices, influences_count, bgfx::AttribType::Int16, false, true);
			assert(!part.joint_weights.empty());
			decl.add(bgfx::Attrib::Weight, influences_count-1, bgfx::AttribType::Float);
		}

		decl.end();
	}
	
	return decl;
}



static void
copy_mesh_part_vertex_elems(const ozz::sample::Mesh::Part &part, uint8_t * &vbPointer) {
	auto copy_elem = [](auto sizeInBytes, auto ptr, auto &dstPtr) {
		memcpy(dstPtr, ptr, sizeInBytes);
		dstPtr += sizeInBytes;
	};

	auto numVertices = part.vertex_count();
	for (auto ii = 0; ii < numVertices; ++ii) {
		copy_elem(ozz::sample::Mesh::Part::kPositionsCpnts * sizeof(float),
			ozz::array_begin(part.positions) + ii, vbPointer);

		if (!part.normals.empty()) {
			copy_elem(ozz::sample::Mesh::Part::kNormalsCpnts * sizeof(float),
				ozz::array_begin(part.normals) + ii, vbPointer);
		}

		if (!part.tangents.empty()) {
			copy_elem(ozz::sample::Mesh::Part::kTangentsCpnts * sizeof(float),
				ozz::array_begin(part.tangents) + ii, vbPointer);
		}

		if (!part.colors.empty()) {
			copy_elem(ozz::sample::Mesh::Part::kColorsCpnts * sizeof(uint8_t),
				ozz::array_begin(part.colors) + ii, vbPointer);
		}

		if (!part.uvs.empty()) {
			copy_elem(ozz::sample::Mesh::Part::kUVsCpnts * sizeof(float),
				ozz::array_begin(part.uvs) + ii, vbPointer);
		}

		size_t influences_count = part.influences_count();
		if (influences_count > 0) {
			copy_elem(influences_count * sizeof(int16_t),
				ozz::array_begin(part.joint_indices) + ii, vbPointer);

			copy_elem((influences_count - 1) * sizeof(float),
				ozz::array_begin(part.joint_weights) + ii, vbPointer);
		}
	}
}



int
convertOZZ(lua_State *L, const std::string &srcpath, const std::string &outputfile, const load_config &config) {
	ozz::sample::Mesh mesh;
	if (!ozz::sample::LoadMesh(srcpath.c_str(), &mesh)) {
		luaL_error(L, "load ozz mesh failed, filename : %s", srcpath.c_str());
	}

	mesh_data md;
	
	md.groups.resize(1);
	auto &group = md.groups.back();

	group.num_vertices = mesh.vertex_count();
	bgfx::VertexDecl decl = get_decl(mesh);
	size_t vbSizeInBytes = decl.getStride() * group.num_vertices;
	group.vbraw = new uint8_t[vbSizeInBytes];
	group.vb_layout = GenVBLayoutFromDecl(decl);

	auto vbPointer = group.vbraw;

	Bounding groupBounding;
	for (auto &part : mesh.parts) {
		copy_mesh_part_vertex_elems(part, vbPointer);
		auto bounding = calc_bounding(part);
		groupBounding.Merge(bounding);
	}

	//{@
	group.ib_format = 16;
	group.num_indices = mesh.triangle_index_count();
	size_t ibSizeInBytes = group.num_indices * sizeof(uint16_t);
	group.ibraw = new uint8_t[ibSizeInBytes];
	memcpy(group.ibraw, ozz::array_begin(mesh.triangle_indices), ibSizeInBytes);
	//@}

	
	group.bounding = groupBounding;
	md.bounding = groupBounding;

	WriteMeshData(md, srcpath, outputfile);
	return 0;
}