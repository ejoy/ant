#include "hierarchy.h"
#include "meshbase/meshbase.h"

extern "C" {
#define LUA_LIB
#include "lua.h"
#include "lauxlib.h"
}

#include <ozz/base/io/archive.h>
#include <../samples/framework/mesh.h>

#include <string>
#include <sstream>

struct ozzmesh {
	ozz::sample::Mesh* mesh;
};

static int
ldel_ozzmesh(lua_State *L) {
	luaL_checktype(L, 1, LUA_TUSERDATA);

	ozzmesh *om = (ozzmesh*)lua_touserdata(L, 1);

	if (om->mesh) {
		OZZ_DELETE(ozz::memory::default_allocator(), om->mesh);
	}

	return 0;
}

static bool 
LoadOzzMesh(const char* _filename, ozz::sample::Mesh* _mesh) {
	assert(_filename && _mesh);
	//ozz::log::Out() << "Loading mesh archive: " << _filename << "." << std::endl;
	ozz::io::File file(_filename, "rb");
	if (!file.opened()) {
		//ozz::log::Err() << "Failed to open mesh file " << _filename << "."
		//	<< std::endl;
		return false;
	}
	ozz::io::IArchive archive(&file);
	if (!archive.TestTag<ozz::sample::Mesh>()) {
		//ozz::log::Err() << "Failed to load mesh instance from file " << _filename
		//	<< "." << std::endl;
		return false;
	}

	// Once the tag is validated, reading cannot fail.
	archive >> *_mesh;

	return true;
}

static int
lnew_ozzmesh(lua_State *L) {
	luaL_checktype(L, 1, LUA_TSTRING);

	const char* filename = lua_tostring(L, 1);

	ozzmesh *om = (ozzmesh*)lua_newuserdatauv(L, sizeof(ozzmesh), 0);
	luaL_getmetatable(L, "OZZMESH");
	lua_setmetatable(L, -2);

	om->mesh = OZZ_NEW(ozz::memory::default_allocator(), ozz::sample::Mesh);
	LoadOzzMesh(filename, om->mesh);
	return 1;
}

static inline ozzmesh*
get_ozzmesh(lua_State *L, int index = 1){
	luaL_checktype(L, 1, LUA_TUSERDATA);
	return (ozzmesh*)lua_touserdata(L, index);
}

static inline size_t
get_partindex(lua_State *L, ozzmesh *om, int index=2){
	luaL_checkinteger(L, index);
	const size_t partidx = (size_t)lua_tointeger(L, index) - 1;

	if (partidx < 0 || om->mesh->parts.size() <= partidx){
		luaL_error(L, "invalid part index:%d, max parts:%d", partidx + 1, om->mesh->parts.size());
		return -1;
	}

	return partidx;
}

static int
linverse_bind_matrices_ozzmesh(lua_State *L){
	auto om = get_ozzmesh(L);
	lua_pushlightuserdata(L, &om->mesh->inverse_bind_poses.front());
	lua_pushinteger(L, om->mesh->inverse_bind_poses.size());
	return 2;
}

static int
llayout_ozzmesh(lua_State *L){
	auto om = get_ozzmesh(L);
	const size_t partidx = lua_isnoneornil(L, 2) ? 0 : get_partindex(L, om);

	lua_createtable(L, 0, 0);

	const auto &part = om->mesh->parts[partidx];

	auto set_elem = [L, part](char shortname, uint32_t numelem, int itemidx, const std::string &def){
		std::string elem(def);
		elem[0] = shortname;
		elem[1] = numelem + '0';
		lua_pushstring(L, elem.c_str());
		lua_seti(L, -2, ++itemidx);
		return itemidx;
	};

	const std::string defelem = "_30NIf";
	
	int arrayidx = set_elem('p', ozz::sample::Mesh::Part::kPositionsCpnts, 0, defelem);

	if (!part.normals.empty()){
		arrayidx = set_elem('n', ozz::sample::Mesh::Part::kNormalsCpnts, arrayidx, defelem);
	}

	if (!part.tangents.empty()){
		arrayidx = set_elem('T', ozz::sample::Mesh::Part::kTangentsCpnts, arrayidx, defelem);
	}

	if (!part.colors.empty()){
		arrayidx = set_elem('c', ozz::sample::Mesh::Part::kColorsCpnts, arrayidx, "_30nIu");
	}

	if (!part.uvs.empty()){
		arrayidx = set_elem('t', ozz::sample::Mesh::Part::kUVsCpnts, arrayidx, defelem);
	}
	
	return 1;
}

static std::vector<std::string>
split_string(const std::string& ss, char delim) {
	std::istringstream iss(ss);
	std::vector<std::string> vv;
	std::string elem;
	while (std::getline(iss, elem, delim)) {
		vv.push_back(elem);
	}

	return vv;
}

static int
lcombinebuffer_ozzmesh(lua_State *L){
	auto om = get_ozzmesh(L);

	const std::string layout = lua_tostring(L, 2);

	auto updatedata = (uint8_t*)lua_touserdata(L, 3);
	auto offset = luaL_optinteger(L, 4, 1) - 1;

	auto outdata = updatedata + offset;

	auto elems = split_string(layout, '|');

	auto cp_vertex_attrib = [](const auto &contanier, uint32_t vertexidx, uint32_t elemnum, uint32_t elemsize, auto &outdata){
		if (contanier.empty())
			return;
		const uint8_t * srcdata = (const uint8_t*)(&contanier.front());
		const auto stride = elemnum * elemsize;
		const auto offset = vertexidx * stride;
		memcpy(outdata, srcdata + offset, stride);
		outdata += stride;
	};

	for (auto &part : om->mesh->parts){
		for (auto ii = 0; ii < part.vertex_count(); ++ii){
			for (auto e : elems){
				switch (e[0]){
					case 'p': cp_vertex_attrib(part.positions, ii, ozz::sample::Mesh::Part::kPositionsCpnts, sizeof(float), outdata); break;
					case 'n': cp_vertex_attrib(part.normals, ii, ozz::sample::Mesh::Part::kNormalsCpnts, sizeof(float), outdata); break;
					case 'T': cp_vertex_attrib(part.tangents, ii, ozz::sample::Mesh::Part::kTangentsCpnts, sizeof(float), outdata); break;
					case 'c': cp_vertex_attrib(part.colors, ii, ozz::sample::Mesh::Part::kColorsCpnts, sizeof(uint8_t), outdata); break;
					case 't': cp_vertex_attrib(part.uvs, ii, ozz::sample::Mesh::Part::kUVsCpnts, sizeof(float), outdata); break;
					case 'w': 
						if (part.influences_count() > 1)
							cp_vertex_attrib(part.joint_weights, ii, part.influences_count() - 1, sizeof(float), outdata);
						break;
					case 'i': cp_vertex_attrib(part.joint_indices, ii, part.influences_count(), sizeof(uint16_t), outdata); break;
					default: return luaL_error(L, "not support layout element:%s", e.c_str());
				}
			}
		}

	}

	return 0;
}

static int
linfluences_count_ozzmesh(lua_State *L){
	auto om = get_ozzmesh(L);
	auto partidx = get_partindex(L, om);

	const auto &part = om->mesh->parts[partidx];
	lua_pushinteger(L, part.influences_count());
	
	return 1;
}

static int
ljoint_remap_ozzmesh(lua_State *L){
	auto om = get_ozzmesh(L);
	lua_pushlightuserdata(L, &om->mesh->joint_remaps.front());
	lua_pushinteger(L, om->mesh->joint_remaps.size());

	return 2;
}

static int
lsize_ozzmesh(lua_State *L){
	auto om = get_ozzmesh(L);

	size_t buffersize = 0;
	for (const auto& p : om->mesh->parts){
		if (!p.positions.empty()){
			buffersize += p.positions.size() * ozz::sample::Mesh::Part::kPositionsCpnts * sizeof(float);
		}

		if (!p.normals.empty()){
			buffersize += p.normals.size() * ozz::sample::Mesh::Part::kNormalsCpnts * sizeof(float);
		}

		if (!p.tangents.empty()){
			buffersize += p.tangents.size() * ozz::sample::Mesh::Part::kTangentsCpnts * sizeof(float);
		}

		if (!p.colors.empty()){
			buffersize += p.colors.size() * ozz::sample::Mesh::Part::kColorsCpnts * sizeof(uint8_t);
		}

		if (!p.uvs.empty()){
			buffersize += p.uvs.size() * ozz::sample::Mesh::Part::kUVsCpnts * sizeof(float);
		}

		if (!p.joint_indices.empty()){
			buffersize += p.joint_indices.size() * p.influences_count() * sizeof(uint16_t);
		}

		if (!p.joint_weights.empty()){
			buffersize += p.joint_weights.size() * (p.influences_count() - 1) * sizeof(float);
		}
	}

	buffersize += om->mesh->triangle_indices.size() * sizeof(uint16_t);
	buffersize += om->mesh->inverse_bind_poses.size() * sizeof(ozz::math::Float4x4);
	buffersize += om->mesh->joint_remaps.size() * sizeof(uint16_t);

	lua_pushinteger(L, buffersize);
	return 1;
}

static int
lvertex_buffer_ozzmesh(lua_State *L){
	auto om = get_ozzmesh(L);

	auto partidx = get_partindex(L, om);

	luaL_checkstring(L, 3);
	const std::string attribname = lua_tostring(L, 3);

	const auto &part = om->mesh->parts[partidx];

	auto push_result = [L](const auto& container, uint32_t stride){
		lua_createtable(L, 3, 0);

		// data
		lua_pushlightuserdata(L, (void*)(&container.front()));
		lua_seti(L, -2, 1);

		// offset
		lua_pushinteger(L, 1);	// no offset, lua index from 1
		lua_seti(L, -2, 2);

		// stride
		lua_pushinteger(L, stride);
		lua_seti(L, -2, 3);
	};

	if (attribname == "POSITION"){
		push_result(part.positions, ozz::sample::Mesh::Part::kPositionsCpnts * sizeof(float));
	}else if(attribname == "NORMAL") {
		if (part.normals.empty())
			return 0;
		push_result(part.normals, ozz::sample::Mesh::Part::kNormalsCpnts * sizeof(float));
	}else if(attribname == "TANGENT"){
		if (part.tangents.empty())
			return 0;
		push_result(part.tangents, ozz::sample::Mesh::Part::kTangentsCpnts * sizeof(float));
	}else if(attribname == "COLOR"){
		if (part.colors.empty())
			return 0;
		push_result(part.colors, ozz::sample::Mesh::Part::kColorsCpnts * sizeof(uint8_t));
	}else if (attribname == "TEXCOORD"){
		if (part.uvs.empty())
			return 0;
		push_result(part.uvs, ozz::sample::Mesh::Part::kUVsCpnts * sizeof(float));
	} else if (attribname == "WEIGHT"){
		if (part.influences_count() <= 1 || part.joint_weights.empty())
			return 0;
		push_result(part.joint_weights, (part.influences_count() - 1) * sizeof(float));
	} else if (attribname == "INDICES"){
		if (part.joint_indices.empty())
			return 0;

		push_result(part.joint_indices, part.influences_count() * sizeof(uint16_t));
	}else{
		return luaL_error(L, "invalid attribute name:%s", attribname.c_str());
	}

	return 1;
}

static int
lnum_vertices_ozzmesh(lua_State *L) {
	ozzmesh *om = get_ozzmesh(L);

	if (lua_isnoneornil(L, 2)){
		lua_pushinteger(L, om->mesh->vertex_count());
	}else {
		const size_t partidx = get_partindex(L, om, 2);
		const auto &part = om->mesh->parts[partidx];
		lua_pushinteger(L, part.positions.size() / ozz::sample::Mesh::Part::kPositionsCpnts);
	}
	
	return 1;
}

static int
lindex_buffer_ozzmesh(lua_State *L){
	auto om = get_ozzmesh(L);
	lua_pushlightuserdata(L, &om->mesh->triangle_indices.front());
	lua_pushinteger(L, 2);	// stride is uint16_t
	return 2;
}

static int
lnum_indices_ozzmesh(lua_State *L) {
	auto om = get_ozzmesh(L);
	lua_pushinteger(L, om->mesh->triangle_index_count());
	return 1;
}

static int
lbounding_ozzmesh(lua_State *L) {
	luaL_checktype(L, 1, LUA_TUSERDATA);
	auto om = (ozzmesh*)lua_touserdata(L, 1);
	om;

	auto push_vec = [L](auto name, auto num, auto obj) {
		lua_createtable(L, num, 0);
		for (auto ii = 0; ii < num; ++ii) {
			lua_pushnumber(L, obj[ii]);
			lua_seti(L, -2, ii + 1);
		}
		lua_setfield(L, -2, name);
	};

	push_vec;
	
	lua_createtable(L, 0, 3);
	assert(false && "need calculate bounding");
	return 1;
}

static int
lnumpart_ozzmesh(lua_State *L){
	auto om = get_ozzmesh(L);
	lua_pushinteger(L, om->mesh->parts.size());
	return 1;
}

static void
register_ozzmesh_mt(lua_State *L) {
	luaL_newmetatable(L, "OZZMESH");
	lua_pushvalue(L, -1);
	lua_setfield(L, -2, "__index");

	luaL_Reg l[] = {		
		{"num_vertices", 	lnum_vertices_ozzmesh},
		{"num_indices", 	lnum_indices_ozzmesh},
		{"index_buffer", 	lindex_buffer_ozzmesh},
		{"vertex_buffer", 	lvertex_buffer_ozzmesh},
		{"bounding", 		lbounding_ozzmesh},
		{"num_part", 		lnumpart_ozzmesh},
		{"inverse_bind_matrices", linverse_bind_matrices_ozzmesh},
		{"layout", 			llayout_ozzmesh},
		{"combine_buffer", 	lcombinebuffer_ozzmesh},
		{"influences_count",linfluences_count_ozzmesh},
		{"joint_remap", 	ljoint_remap_ozzmesh},
		{"size", 			lsize_ozzmesh},
		{"__gc", 			ldel_ozzmesh},
		{nullptr, nullptr},
	};

	luaL_setfuncs(L, l, 0);
}

extern "C" {
LUAMOD_API int
luaopen_hierarchy_ozzmesh(lua_State *L) {
    register_ozzmesh_mt(L);
    luaL_Reg l[] = {
        {"new", lnew_ozzmesh},
        {nullptr, nullptr,}
    };

    luaL_newlib(L, l);
    return 1;
}
}