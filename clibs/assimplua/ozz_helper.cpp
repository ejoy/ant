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

static std::string get_vblayout(const ozz::sample::Mesh &mesh) {
	std::string layout;
	//if (!mesh.parts.empty()) {
	//	auto &part
	//}

	return layout;
}

//static bgfx::VertexDecl get_decl(const ozz::sample::Mesh &mesh) {
//	bgfx::VertexDecl decl;
//	if (!mesh.parts.empty()) {
//		auto &part = mesh.parts.back();
//
//		decl.begin();
//
//		if (!part.positions.empty()) {
//			decl.add(bgfx::Attrib::Position, ozz::sample::Mesh::Part::kPositionsCpnts, bgfx::AttribType::Float);
//		}
//		
//		if (!part.normals.empty()) {
//			decl.add(bgfx::Attrib::Normal, ozz::sample::Mesh::Part::kNormalsCpnts, bgfx::AttribType::Float, true);
//		}
//
//		if (!part.tangents.empty()) {
//			decl.add(bgfx::Attrib::Tangent, ozz::sample::Mesh::Part::kTangentsCpnts, bgfx::AttribType::Float, true);
//		}
//
//		if (!part.colors.empty()) {
//			decl.add(bgfx::Attrib::Color0, ozz::sample::Mesh::Part::kColorsCpnts, bgfx::AttribType::Uint8, true, true);
//		}
//
//		if (!part.uvs.empty()) {
//			decl.add(bgfx::Attrib::TexCoord0, ozz::sample::Mesh::Part::kUVsCpnts, bgfx::AttribType::Float);
//		}
//
//		auto influences_count = part.influences_count();
//		if (influences_count > 0) {
//			assert(!part.joint_indices.empty());
//			decl.add(bgfx::Attrib::Indices, influences_count, bgfx::AttribType::Int16, false, true);
//			assert(!part.joint_weights.empty());
//			decl.add(bgfx::Attrib::Weight, influences_count-1, bgfx::AttribType::Float);
//		}
//
//		decl.end();
//	}
//	
//	return decl;
//}



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

static std::string
create_vb_layout(const ozz::sample::Mesh &mesh) {
	const auto &part = mesh.parts.back();
	
	std::string layout;
	std::string def = GetDefaultVertexLayoutElem();

	assert(!part.positions.empty());
	std::string pos = def;
	pos[0] = 'p';
	pos[1] = ozz::sample::Mesh::Part::kPositionsCpnts + '0';
	layout += pos;

	if (!part.normals.empty()) {
		std::string normal = def;
		normal[0] = 'n';
		normal[1] = ozz::sample::Mesh::Part::kNormalsCpnts + '0';
		normal[3] = 'n';	// have been normalize
		layout += normal;
	}


	if (!part.tangents.empty()) {
		std::string tangent = def;
		tangent[0] = 'T';
		tangent[1] = ozz::sample::Mesh::Part::kTangentsCpnts + '0';
		tangent[3] = 'n';
		layout += tangent;
	}

	if (!part.colors.empty()) {
		std::string color = def;
		color[0] = 'c';
		color[1] = ozz::sample::Mesh::Part::kColorsCpnts + '0';
		color[3] = 'n';
		layout += color;
	}

	if (!part.uvs.empty()) {
		std::string tex = def;
		tex[0] = 't';
		tex[1] = ozz::sample::Mesh::Part::kUVsCpnts + '0';
		tex[3] = 'n';
		layout += tex;
	}

	auto maxinf = mesh.max_influences_count();
	if (maxinf > 0) {
		std::string indices = def;
		indices[0] = 'i';
		indices[1] = maxinf + '0';
		indices[4] = 'i';	// as int
		indices[5] = 'u';	// as uint8
		layout += indices;
	}

	if (maxinf > 1) {
		std::string weight = def;
		weight[0] = 'w';
		weight[1] = maxinf - 1 + '0';
		layout += weight;
	}

	return layout;
}


static void
init_vertex_buffer(const ozz::sample::Mesh &mesh, vb_info &vb) {
	assert(vb.soa);

	auto maxinf = mesh.max_influences_count();	
	auto calc_size = [](const ozz::sample::Mesh &mesh, const std::string &elem) {
		size_t sizeInBytes = 0;
		const size_t count = elem[1] - '0';
		switch (elem[0])
		{
		case 'p': {			
			for (const auto &p : mesh.parts)
				sizeInBytes += p.positions.size() * count * sizeof(float);
			break;
		}			
		case 'n': {
			for (const auto &p : mesh.parts)
				sizeInBytes += p.normals.size() * count * sizeof(float);

			break;
		}
			
		case 'T': {
			for (const auto &p : mesh.parts)
				sizeInBytes += p.tangents.size() * count * sizeof(float);

			break;
		}
		case 't': {
			for (const auto &p : mesh.parts)
				sizeInBytes += p.uvs.size() * count * sizeof(float);

			break;
		}
		case 'c': {
			for (const auto &p : mesh.parts)
				sizeInBytes += p.colors.size() * count * sizeof(float);

			break;
		}

		case 'i': {
			for (const auto &p : mesh.parts)
				sizeInBytes += p.joint_indices.size() * count * sizeof(uint8_t);

			break;
		}
		case 'w': {
			for (const auto &p : mesh.parts)
				sizeInBytes += p.joint_weights.size() * count * sizeof(float);

			break;
		}

		default:
			break;
		}
		return sizeInBytes;
	};

	auto elems = AdjustLayoutElem(vb.layout);
	std::map<char, size_t>	elem_ptr_mapper;
	for (const auto &e : elems) {
		auto sizeInBytes = calc_size(mesh, e);
		const auto idx = vb.vbraws.size();
		elem_ptr_mapper[e[0]] = idx;
		vb.vbraws.push_back(std::make_unique<uint8_t[]>(sizeInBytes));		
	}
	
	size_t startVB = 0;
	for (auto &part : mesh.parts) {
		assert(!part.positions.empty());

		auto copy_data = [&elem_ptr_mapper, &vb](size_t startVB, char elemName, size_t elemSize, auto &srcArray) {
			const auto idx = elem_ptr_mapper[elemName];
			auto &ptr = vb.vbraws[idx];			
			memcpy(ptr.get(), ozz::array_begin(srcArray), startVB * elemSize + srcArray.size() * elemSize);
		};

		copy_data(startVB, 'p', ozz::sample::Mesh::Part::kPositionsCpnts * sizeof(float), part.positions);		
		copy_data(startVB, 'n', ozz::sample::Mesh::Part::kNormalsCpnts * sizeof(float), part.normals);
		copy_data(startVB, 'T', ozz::sample::Mesh::Part::kTangentsCpnts * sizeof(float), part.tangents);
		copy_data(startVB, 'c', ozz::sample::Mesh::Part::kColorsCpnts * sizeof(float), part.colors);
		copy_data(startVB, 't', ozz::sample::Mesh::Part::kUVsCpnts * sizeof(float), part.uvs);

		
		if (maxinf > 0)
			copy_data(startVB, 'i', maxinf * sizeof(uint16_t), part.joint_indices);
		if (maxinf > 1)
			copy_data(startVB, 'w', (maxinf - 1) * sizeof(float), part.joint_weights);

		startVB += part.positions.size();
	}
}


bool
convertOZZ(lua_State *L, const std::string &srcpath, const std::string &outputfile, const load_config &config) {
	ozz::sample::Mesh mesh;
	if (!ozz::sample::LoadMesh(srcpath.c_str(), &mesh)) {
		luaL_error(L, "load ozz mesh failed, filename : %s", srcpath.c_str());
		return false;
	}

	mesh_data md;
	
	md.groups.resize(1);
	auto &group = md.groups.back();
	auto &vb = group.vb;

	vb.soa = true;	// always true for ozz mesh
	vb.num_vertices = mesh.vertex_count();
	vb.layout = create_vb_layout(mesh);
	
	init_vertex_buffer(mesh, vb);
	

	//auto vbPointer = group.vbraw;
	Bounding groupBounding;
	for (auto &part : mesh.parts) {	
		auto bounding = calc_bounding(part);
		groupBounding.Merge(bounding);
	}

	//{@
	auto &ib = group.ib;
	ib.format = 16;
	ib.num_indices = mesh.triangle_index_count();
	size_t ibSizeInBytes = ib.num_indices * sizeof(uint16_t);
	ib.ibraw = new uint8_t[ibSizeInBytes];
	memcpy(ib.ibraw, ozz::array_begin(mesh.triangle_indices), ibSizeInBytes);
	//@}

	
	group.bounding = groupBounding;
	md.bounding = groupBounding;

	if (!WriteMeshData(md, srcpath, outputfile)) {
		luaL_error(L, "after convert ozz mesh, but write to antmesh failed!");
		return false;
	}
	return true;
}