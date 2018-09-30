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

	auto append_elem = [&layout](const std::string &e) {
		if (layout.empty())
			layout = e;
		else
			layout += "|" + e;
	};

	assert(!part.positions.empty());
	std::string pos = def;
	pos[0] = 'p';
	pos[1] = ozz::sample::Mesh::Part::kPositionsCpnts + '0';	
	append_elem(pos);

	if (!part.normals.empty()) {
		std::string normal = def;
		normal[0] = 'n';
		normal[1] = ozz::sample::Mesh::Part::kNormalsCpnts + '0';
		normal[3] = 'n';	// have been normalize		
		append_elem(normal);
	}

	if (!part.tangents.empty()) {
		std::string tangent = def;
		tangent[0] = 'T';
		tangent[1] = ozz::sample::Mesh::Part::kTangentsCpnts + '0';
		tangent[3] = 'n';
		
		append_elem(tangent);
	}

	if (!part.colors.empty()) {
		std::string color = def;
		color[0] = 'c';
		color[1] = ozz::sample::Mesh::Part::kColorsCpnts + '0';
		color[3] = 'n';
		append_elem(color);
	}

	if (!part.uvs.empty()) {
		std::string tex = def;
		tex[0] = 't';
		tex[1] = ozz::sample::Mesh::Part::kUVsCpnts + '0';
		tex[3] = 'n';
		append_elem(tex);		
	}

	auto maxinf = mesh.max_influences_count();
	if (maxinf > 0) {
		std::string indices = def;
		indices[0] = 'i';
		indices[1] = maxinf + '0';
		indices[4] = 'i';	// as int
		indices[5] = 'u';	// as uint8		
		append_elem(indices);
	}

	if (maxinf > 1) {
		std::string weight = def;
		weight[0] = 'w';
		weight[1] = maxinf - 1 + '0';
		append_elem(weight);		
	}

	return layout;
}


static void
init_vertex_buffer(const ozz::sample::Mesh &mesh, const load_config &config, vb_info &vb) {
	assert(vb.soa);

	auto maxinf = mesh.max_influences_count();	
	auto calc_size = [](const ozz::sample::Mesh &mesh, const std::string &elem) {
		size_t sizeInBytes = 0;
		
		switch (elem[0])
		{
		case 'p': {			
			for (const auto &p : mesh.parts)
				sizeInBytes += p.positions.size() * sizeof(float);				
			break;
		}			
		case 'n': {
			for (const auto &p : mesh.parts)
				sizeInBytes += p.normals.size() * sizeof(float);

			break;
		}
			
		case 'T': {
			for (const auto &p : mesh.parts)
				sizeInBytes += p.tangents.size() * sizeof(float);

			break;
		}
		case 't': {
			for (const auto &p : mesh.parts)
				sizeInBytes += p.uvs.size() * sizeof(float);

			break;
		}
		case 'c': {
			for (const auto &p : mesh.parts)
				sizeInBytes += p.colors.size() * sizeof(float);

			break;
		}

		case 'i': {			
			size_t maxinf = mesh.max_influences_count();

			for (const auto &p : mesh.parts) {
				size_t inf = p.influences_count();

				size_t size = (p.joint_indices.size() / inf) * maxinf;
				sizeInBytes += size * sizeof(uint8_t);
			}
			
			break;
		}
		case 'w': {
			size_t maxinf = mesh.max_influences_count() - 1;

			for (const auto &p : mesh.parts) {
				if (p.joint_weights.empty())
					continue;

				size_t inf = p.influences_count() - 1;
				size_t size = (p.joint_weights.size() / inf) * maxinf;

				sizeInBytes += size * sizeof(float);
			}
				

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
		vb.vbraws.push_back(std::move(rawbuffer(sizeInBytes)));
	}
	
	size_t startVB = 0;
	size_t weightOffset = 0;
	for (auto &part : mesh.parts) {
		assert(!part.positions.empty());

		auto copy_data = [&elem_ptr_mapper, &vb](size_t offset, char elemName, size_t elemSize, auto &srcArray) {
			const auto idx = elem_ptr_mapper[elemName];
			auto &ptr = vb.vbraws[idx];			
			memcpy(ptr.data + offset, ozz::array_begin(srcArray), srcArray.size() * elemSize);
		};

		copy_data(startVB * ozz::sample::Mesh::Part::kPositionsCpnts * sizeof(float),	'p', sizeof(float), part.positions);		
		copy_data(startVB * ozz::sample::Mesh::Part::kNormalsCpnts * sizeof(float),		'n', sizeof(float), part.normals);
		copy_data(startVB * ozz::sample::Mesh::Part::kTangentsCpnts * sizeof(float),	'T', sizeof(float), part.tangents);
		copy_data(startVB * ozz::sample::Mesh::Part::kColorsCpnts * sizeof(float),		'c', sizeof(float), part.colors);
		copy_data(startVB * ozz::sample::Mesh::Part::kUVsCpnts * sizeof(float),			't', sizeof(float), part.uvs);

		auto inf = part.influences_count();
		
		if (inf > 0) {
			const auto idx = elem_ptr_mapper['i'];
			auto &ptr = vb.vbraws[idx];
			uint8_t *data = ptr.data + startVB * maxinf;
			for (size_t iV = 0; iV < part.vertex_count(); ++iV) {
				for (size_t iInf = 0; iInf < inf; ++iInf) {
					size_t idx = iV * inf + iInf;
					uint16_t joint_idx = part.joint_indices[idx];
					assert(joint_idx < 256);
					size_t dataidx = iV * maxinf + iInf;
					data[dataidx] = (uint8_t)joint_idx;
				}

				for (size_t iInfLeft = inf; iInfLeft < maxinf; ++iInfLeft) {
					data[iV * maxinf + iInfLeft] = 0;
				}
			}
		}
			
		if (inf > 1) {
			const auto idx = elem_ptr_mapper['w'];
			auto &ptr = vb.vbraws[idx];

			const size_t weight_inf = inf - 1;
			const size_t max_weight_inf = maxinf - 1;

			float *data = (float*)ptr.data + weightOffset * max_weight_inf;

			for (size_t iV = 0; iV < part.vertex_count(); ++iV) {
				const size_t data_vertex_idx = iV * max_weight_inf;
				const size_t joint_vertex_idx = iV * weight_inf;

				for (size_t iInf = 0; iInf < weight_inf; ++iInf) {
					const size_t idx = iV * weight_inf + iInf;
					float weight = part.joint_weights[idx];					
					const size_t dataidx = data_vertex_idx + iInf;
					data[dataidx] = weight;
				}

				for (size_t iInfLeft = weight_inf; iInfLeft < max_weight_inf; ++iInfLeft) {
					data[data_vertex_idx + iInfLeft] = 0;
				}
			}

			weightOffset += part.vertex_count();
		}
		
		startVB += part.vertex_count();
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
	
	init_vertex_buffer(mesh, config, vb);
	

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