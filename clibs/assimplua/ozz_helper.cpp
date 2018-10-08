#include "meshdata.h"
#include "utils.h"

extern "C" {
#define LUA_LIB
#include "lua.h"
#include "lauxlib.h"
}

// ozz
#include "ozz-animation/samples/framework/mesh.h"
#include "ozz-animation/samples/framework/utils.h"


static Bounding calc_bounding(const ozz::sample::Mesh::Part &part) {
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
	for (const auto &e : elems) {
		auto sizeInBytes = calc_size(mesh, e);
		const std::string streamName = GenStreamNameFromElem(e);

		vb.vbraws[streamName] = std::move(rawbuffer(sizeInBytes));
	}
	
	size_t startVB = 0;
	size_t weightOffset = 0;
	for (auto &part : mesh.parts) {
		assert(!part.positions.empty());

		auto copy_data = [&vb](size_t offset, const std::string& elemName, size_t elemSize, auto &srcArray) {			
			auto &ptr = vb.vbraws[elemName];
			memcpy(ptr.data + offset, ozz::array_begin(srcArray), srcArray.size() * elemSize);
		};

		copy_data(startVB * ozz::sample::Mesh::Part::kPositionsCpnts * sizeof(float),	"p", sizeof(float), part.positions);		
		copy_data(startVB * ozz::sample::Mesh::Part::kNormalsCpnts * sizeof(float),		"n", sizeof(float), part.normals);
		copy_data(startVB * ozz::sample::Mesh::Part::kTangentsCpnts * sizeof(float),	"T", sizeof(float), part.tangents);
		copy_data(startVB * ozz::sample::Mesh::Part::kColorsCpnts * sizeof(float),		"c0", sizeof(float), part.colors);
		copy_data(startVB * ozz::sample::Mesh::Part::kUVsCpnts * sizeof(float),			"t0", sizeof(float), part.uvs);

		auto inf = part.influences_count();
		
		if (inf > 0) {			
			auto &ptr = vb.vbraws["i"];
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
			auto &ptr = vb.vbraws["w"];

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

static int
lnew_sample_mesh(lua_State *L) {
	luaL_checktype(L, 1, LUA_TSTRING);
	const char* ozzmeshfilename = lua_tostring(L, 1);

	ozz::sample::Mesh mesh;
	if (!ozz::sample::LoadMesh(ozzmeshfilename, &mesh)) {
		luaL_error(L, "load ozz mesh failed, filename : %s", ozzmeshfilename);
		return 0;
	}

	lua_newtable(L);		// mesh
	luaL_getmetatable(L, "SAMPLE_MESH");
	lua_setmetatable(L, -2);

	lua_pushinteger(L, mesh.vertex_count());
	lua_setfield(L, -2, "vertex_count");

	// mesh.parts
	if (!mesh.parts.empty()) {
		Bounding bounding;
		lua_createtable(L, 0, 0);

		for (size_t ipart = 0; ipart < mesh.parts.size(); ++ipart) {
			const auto &part = mesh.parts[ipart];
			lua_newtable(L);	// part begin

			auto push_attrib = [L](auto elem_count, auto elemtype, auto elemsize, auto name, const auto& srcarray) {
				lua_createtable(L, 0, 3);
				lua_pushlstring(L, (const char*)ozz::array_begin(srcarray), srcarray.size() * elemsize);
				lua_setfield(L, -2, "data");

				lua_pushinteger(L, elem_count);
				lua_setfield(L, -2, "count");

				lua_pushstring(L, elemtype);
				lua_setfield(L, -2, "type");

				lua_setfield(L, -2, name);	// set to part table
			};

			push_attrib(ozz::sample::Mesh::Part::kPositionsCpnts, "f", sizeof(float), "position", part.positions);

			push_attrib(ozz::sample::Mesh::Part::kNormalsCpnts, "f", sizeof(float), "normal", part.normals);
			push_attrib(ozz::sample::Mesh::Part::kTangentsCpnts, "f", sizeof(float), "tangent", part.tangents);

			push_attrib(ozz::sample::Mesh::Part::kColorsCpnts, "u", sizeof(uint8_t), "color", part.colors);
			push_attrib(ozz::sample::Mesh::Part::kUVsCpnts, "f", sizeof(float), "texcoord", part.uvs);

			auto inf = part.influences_count();
			if (inf > 0) {
				push_attrib(inf, "S", sizeof(uint16_t), "indices", part.joint_indices);
			}

			if (inf > 1) {
				push_attrib(inf - 1, "f", sizeof(float), "weights", part.joint_weights);
			}

			lua_seti(L, -2, ipart + 1);	// set to mesh table


			Bounding partBounding = calc_bounding(part);
			bounding.Merge(partBounding);
		}

		lua_setfield(L, -2, "parts");

		// add bounding
		{
			lua_createtable(L, 0, 2);

			auto add_vec3 = [L](auto v, auto name) {
				lua_createtable(L, 3, 0);
				for (auto ii = 0; ii < 3; ++ii) {
					lua_pushnumber(L, v[ii]);
					lua_seti(L, -2, ii + 1);
				}
				lua_setfield(L, -2, name);
			};

			lua_createtable(L, 0, 2);	// box	
			add_vec3(bounding.aabb.min, "min");
			add_vec3(bounding.aabb.max, "max");			
			lua_setfield(L, -2, "aabb");

			lua_createtable(L, 0, 2);	//sphere
			lua_pushnumber(L, bounding.sphere.radius);
			lua_setfield(L, -2, "radius");
			add_vec3(bounding.sphere.center, "center");
			lua_setfield(L, -2, "sphere");

			lua_setfield(L, -2, "bounding");
		}
	}

	// mesh.indices
	if (!mesh.triangle_indices.empty()) {
		lua_createtable(L, 0, 2);
		lua_pushlstring(L, (const char*)ozz::array_begin(mesh.triangle_indices), mesh.triangle_indices.size() * sizeof(uint16_t));
		lua_setfield(L, -2, "data");
		
		lua_pushinteger(L, sizeof(uint16_t));
		lua_setfield(L, -2, "format");

		lua_setfield(L, -2, "indices");	// set mesh.indices = indices
	}

	// mesh.joint_remaps
	if (!mesh.joint_remaps.empty()) {
		lua_createtable(L, 0, 2);
		lua_pushlstring(L, (const char*)ozz::array_begin(mesh.joint_remaps), mesh.joint_remaps.size() * sizeof(uint16_t));
		lua_setfield(L, -2, "data");

		lua_pushinteger(L, sizeof(uint16_t));
		lua_setfield(L, -2, "format");

		lua_setfield(L, -2, "joint_remaps");
	}

	// mesh.inverse_bind_poses
	if (!mesh.inverse_bind_poses.empty()) {
		lua_createtable(L, int(mesh.inverse_bind_poses.size() * 16), 0);

		uint32_t idx = 0;
		for (const auto &pose : mesh.inverse_bind_poses) {
			for (uint32_t iCol = 0; iCol < 4; ++iCol) {
				for (uint32_t iRow = 0; iRow < 4; ++iRow) {
					lua_pushnumber(L, pose.cols[iCol].m128_f32[iRow]);
					lua_seti(L, -2, idx + iCol * 4 + iRow + 1);
				}
			}
			idx += 16;
		}

		lua_setfield(L, -2, "inverse_bind_poses");
	}

	return 1;
}

extern "C" {
LUAMOD_API int
luaopen_assimplua_ozzmesh(lua_State *L) {
	luaL_newmetatable(L, "SAMPLE_MESH");
	lua_pushvalue(L, -1);
	lua_setfield(L, -2, "__index");	// ANIMATION_NODE.__index = ANIMATION_NODE

	luaL_Reg l[] = {
		{ "new_ozzmesh", lnew_sample_mesh},	
		{ NULL, NULL },
	};
	luaL_newlib(L, l);

	return 1;
}
}