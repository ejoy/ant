#include "meshdata.h"
#include "utils.h"
extern "C" {
	#include <lua.h>  
	#include <lualib.h>
	#include <lauxlib.h>
}

//assimp include
#include <assimp/importer.hpp>
#include <assimp/postprocess.h>
#include <assimp/scene.h>

//bgfx include
#include <bx/string.h>
#include <bx/file.h>
#include <bgfx/bgfx.h>
#include <bgfx_utils.h>
#include <vertexdecl.h>
#include <../../3rdparty/ib-compress/indexbufferdecompression.h>


//glm
#include <glm/glm.hpp>

//stl
#include <set>
#include <algorithm>
#include <unordered_map>
#include <functional>
#include <sstream>
#include <fstream>
#include <type_traits>
#include <memory>

//c std
#include <cassert>

static void
ExtractLoadConfig(lua_State *L, int idx, load_config &config) {
	luaL_checktype(L, idx, LUA_TTABLE);

	verify(lua_getfield(L, idx, "layout") == LUA_TSTRING);

	config.layout = lua_tostring(L, -1);
	lua_pop(L, 1);

	verify(LUA_TTABLE == lua_getfield(L, -1, "flags"));

	auto extract_boolean = [&](auto name, auto bit) {
		const int type = lua_getfield(L, -1, name);
		const bool need = type == LUA_TBOOLEAN ? lua_toboolean(L, -1) != 0 : false;
		if (need)
			config.flags |= bit;
		else
			config.flags &= ~bit;
		lua_pop(L, 1);
	};

	auto elems = Split(config.layout, '|');
	if (std::find_if(std::begin(elems), std::end(elems), [](auto e) {return e[0] == 'n'; }) != std::end(elems))
		config.flags |= load_config::CreateNormal;

	if (std::find_if(std::begin(elems), std::end(elems), [](auto e) {return e[0] == 'T' || e[0] == 'b';}) != std::end(elems))
		config.flags |= load_config::CreateTangent|load_config::CreateBitangent;

	extract_boolean("invert_normal", load_config::InvertNormal);
	extract_boolean("flip_uv", load_config::FlipUV);
	extract_boolean("ib_32", load_config::IndexBuffer32Bit);
}

static inline void WriteSize(std::ostream &os, const std::string &elem, size_t valueSize) {
	uint32_t elemsize = uint32_t(elem.size());
	uint32_t fullsize = uint32_t(elemsize + valueSize) + 8;	// 8 is fullsize and elemsize
	os.write((const char*)&fullsize, sizeof(uint32_t));
	os.write((const char*)&elemsize, sizeof(uint32_t));
}

template<typename T, bool standlayout=std::is_standard_layout<T>::value >
static void WriteElemValue(std::ostream &os, const std::string& elem, const T* value, size_t sizeInBytes) {
	static_assert(standlayout, "need stand layout object");

	WriteSize(os, elem, sizeInBytes);	
	os.write(elem.c_str(), elem.size());	
	os.write((const char*)value, sizeInBytes);
}

template<typename T, bool standlayout = std::is_standard_layout<T>::value>
static void WriteElemValue(std::ostream &os, const std::string& elem, const T& value) {
	WriteElemValue(os, elem, &value, sizeof(T));
}

static void WriteElemValue(std::ostream &os, const std::string &elem, const std::string &value) {
	WriteElemValue(os, elem, value.c_str(), value.size());
}

static void WriteElemValue(std::ostream &os, const std::string& elem) {
	WriteSize(os, elem, 0);
	os.write(elem.c_str(), elem.size());
}

static void WriteSeparator(std::ostream &os) {
	uint32_t s = 0;
	os.write((const char*)&s, sizeof(uint32_t));
}

bool
WriteMeshData(const mesh_data &md, const std::string &srcfile, const std::string &outputfile) {
	std::ofstream off(outputfile, std::ios::binary);
	if (!off) {
		return false;		
	}

	WriteElemValue(off, "version", std::to_string(MESH_DATA_VERSION));

	auto write_bounding = [](std::ostream &off, const Bounding &bounding) {
		WriteElemValue(off, "bounding"); {
			WriteElemValue(off, "aabb"); {
				WriteElemValue(off, "min", bounding.aabb.min);
				WriteElemValue(off, "max", bounding.aabb.max);				
			}
			WriteSeparator(off);

			WriteElemValue(off, "sphere"); {
				WriteElemValue(off, "center", bounding.sphere.center);
				WriteElemValue(off, "radius", bounding.sphere.radius);
			}
			WriteSeparator(off);
		}
		WriteSeparator(off);
	};

	WriteElemValue(off, "srcfile", srcfile);
	write_bounding(off, md.bounding);
	
	WriteElemValue(off, "materials");
	for (auto &material : md.materials) {
		WriteElemValue(off, "name", material.name);

		WriteElemValue(off, "textures");
		for (const auto &texture : material.textures) {
			WriteElemValue(off, texture.first, texture.second);
		}
		WriteSeparator(off);	// end textures
		

		WriteElemValue(off, "colors");
		for (const auto &color : material.colors) {			
			WriteElemValue(off, color.first, color.second);			
		}
		WriteSeparator(off);	// end colors		

		WriteSeparator(off);	// end material
	}
	WriteSeparator(off);	// end materials

	WriteElemValue(off, "groups");
	for (const auto &g : md.groups) {
		write_bounding(off, g.bounding);
		WriteElemValue(off, "name", g.name);

		const auto &vb = g.vb;
		WriteElemValue(off, "vb"); {
			WriteElemValue(off, "layout", vb.layout);
			WriteElemValue(off, "num_vertices", vb.num_vertices);
			WriteElemValue(off, "vbraws"); {
				// make as struct NOT array, so only call WriteSeparator one time
				for (uint8_t ii = 0; ii < vb.vbraws.size(); ++ii) {
					const auto &vbraw = vb.vbraws[ii];
					WriteElemValue(off, std::to_string(ii), vbraw.data, vbraw.size);
				}
				WriteSeparator(off);
			}
			WriteElemValue(off, "soa", vb.soa);
			WriteSeparator(off);	// end vb
		}
		
		const auto &ib = g.ib;
		if (ib.num_indices != 0) {
			WriteElemValue(off, "ib"); {
				WriteElemValue(off, "format", ib.format);
				WriteElemValue(off, "num_indices", ib.num_indices);
				WriteElemValue(off, "ibraw", reinterpret_cast<const char*>(ib.ibraw), (ib.format == 16 ? 2 : 4) * ib.num_indices);
				WriteSeparator(off);
			}
		}

		if (!g.primitives.empty()) {
			WriteElemValue(off, "primitives"); {
				for (const auto &p : g.primitives) {
					write_bounding(off, p.bounding);

					WriteElemValue(off, "transform", p.transform);
					WriteElemValue(off, "name", p.name);

					WriteElemValue(off, "material_idx", p.material_idx);

					WriteElemValue(off, "start_vertex", p.start_vertex);
					WriteElemValue(off, "num_vertices", p.num_vertices);

					WriteElemValue(off, "start_index", p.start_index);
					WriteElemValue(off, "num_indices", p.num_indices);

					WriteSeparator(off);	// end primitive
				}
				WriteSeparator(off);	// end primitives
			}
		}
		
		WriteSeparator(off);	// end group
	}
	WriteSeparator(off);	// end groups
	return true;
}

static int 
convertSource(lua_State *L, std::function<bool (lua_State *, const std::string&, const std::string &, const load_config &)> convertop) {
	luaL_checktype(L, 1, LUA_TSTRING);
	luaL_checktype(L, 2, LUA_TSTRING);
	luaL_checktype(L, 3, LUA_TTABLE);

	const std::string src_path = lua_tostring(L, 1);
	const std::string output_path = lua_tostring(L, 2);

	load_config config;
	ExtractLoadConfig(L, 3, config);
	convertop(L, src_path, output_path, config);
	return 0;
}

extern bool
convertBGFX(lua_State *L, const std::string &srcpath, const std::string &outputfile, const load_config &config);

int 
lconvertBGFXBin(lua_State *L) {
	return convertSource(L, convertBGFX);	
}

extern bool
convertFBX(lua_State *L, const std::string &srcpath, const std::string &outputfile, const load_config &config);

int
lconvertFBX(lua_State *L) {	
	return convertSource(L, convertFBX);
}

extern bool
convertOZZ(lua_State *L, const std::string &srcpath, const std::string &outputfile, const load_config &config);

int
lconvertOZZMesh(lua_State *L) {
	return convertSource(L, convertOZZ);
}


// due to example-commonDebug/Release.lib need _main_, we should add ENTRY_CONFIG_IMPLEMENT_MAIN macro when compile bgfx lib, or define
// by myself.
extern "C" {
	int32_t _main_(int32_t _argc, char** _argv) {
		return 0;
	}
}



