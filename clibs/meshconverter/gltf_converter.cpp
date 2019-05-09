#include "common.h"
#include "meshdata.h"
#include "utils.h"

extern "C"
{
#include <lua.h>  
#include <lualib.h>
#include <lauxlib.h>
}

#include <bgfx/bgfx.h>

#include <string>
#include <vector>
#include <map>
#include <algorithm>
#include <sstream>

#include <cassert>

struct primitive {
	struct bufferview {
		uint32_t index;
		uint32_t offset;
		uint32_t length;
		uint32_t stride;
		uint32_t target;
	};

	struct accessor {
		bufferview bv;
		uint32_t offset;
		uint32_t comptype;
		uint8_t normalized;
		uint8_t elemcount;
		uint8_t type;
		uint8_t padding;
		uint32_t minvalue_count;
		float minvalues[16];
		uint32_t maxvalue_count;
		float maxvalues[16];
	};

	
	std::map<uint32_t, accessor> attributes;	// need order
	accessor	indices;
};

struct attrib_name {
	const char* name;
	const char* sname;
	uint32_t channel;
};

static attrib_name attribname_mapper[] = {
	{"POSITION", "p", 0},

	{"NORMAL", "n", 0},
	{"TANGENT", "T", 0},
	{"BITANGENT", "b", 0},

	{"COLOR_0", "c", 0},
	{"COLOR_1", "c", 1},
	{"COLOR_2", "c", 2},
	{"COLOR_3",	"c", 3 },

	{ "TEXCOORD_0", "t", 0 },
	{ "TEXCOORD_1", "t", 1 },
	{ "TEXCOORD_2", "t", 2 },
	{ "TEXCOORD_3", "t", 3 },
	{ "TEXCOORD_4", "t", 4 },
	{ "TEXCOORD_5", "t", 5 },
	{ "TEXCOORD_6", "t", 6 },
	{ "TEXCOORD_7", "t", 7 },

	{"WEIGHT", "w", 0},
	{"INDICES", "i", 0},
};


struct elem_type {
	const char* name;
	uint32_t elem_count;
};

static elem_type elem_type_mapper[] = {
	{"SCALAR", 1},
	{"VEC2", 2},
	{"VEC3", 3},
	{"VEC4", 4},
	{"MAT2", 4},
	{"MAT3", 9},
	{"MAT4", 16},	
};

struct attribute_buffer {
	uint32_t buffersize;
	uint8_t *data;
};

struct bufferinfo {
	uint32_t attribname;
	primitive::accessor *accessor;
};
using bufferinfo_array = std::vector<bufferinfo>;
using bufferview_index = uint32_t;
using buffer_desc = std::vector<std::pair<bufferview_index, bufferinfo_array>>;

static bool 
fetch_primitive(lua_State *L, int index,  primitive &prim) {
	size_t size_bytes = 0;
	const char* serializedata = luaL_checklstring(L, index, &size_bytes);

	const uint32_t numattrib = *((uint32_t*)serializedata);	

	// read attributes
	const char* attrib_data = serializedata + sizeof(uint32_t);
	for (uint32_t ii = 0; ii < numattrib; ++ii) {		
		uint32_t attribname = *(uint32_t*)(attrib_data);
		attrib_data += sizeof(uint32_t);
		const primitive::accessor* accessor_data = (const primitive::accessor*)(attrib_data);
		prim.attributes[attribname] = *accessor_data;
	}

	// read indices accessor
	const int64_t byteleft = serializedata - attrib_data;
	if (byteleft < (int64_t)size_bytes) {
		if (byteleft != sizeof(primitive::accessor)) {
			return false;
		}
	}
	prim.indices = *(const primitive::accessor*)(attrib_data);
	return true;
}

enum ComponentType : uint16_t {
	BYTE = 5120,
	UNSIGNED_BYTE = 5121,
	SHORT = 5122,
	UNSIGNED_SHORT = 5123,
	UNSIGNED_INT = 5125,
	FLOAT = 5126,
};

static std::string
decl_desc(uint32_t attribname, const primitive::accessor *accessor) {
	char elem[6];

	auto to_type = [](auto v) {
		switch (v) {
		case ComponentType::BYTE:
		case ComponentType::UNSIGNED_BYTE:
			return 'u';
		case ComponentType::SHORT:
		case ComponentType::UNSIGNED_SHORT:
			return 'i';
		case ComponentType::FLOAT:
			return 'f';
		default:
			return 'f';
		}
	};


	assert(attribname < sizeof(attribname_mapper[0]) / sizeof(attribname_mapper[0]));

	const auto& attrib = attribname_mapper[attribname];

	elem[0] = attrib.sname[0];
	elem[1] = '0' + accessor->elemcount;
	elem[2] = '0' + attrib.channel;
	elem[3] = accessor->normalized ? 'n' : 'N';
	elem[4] = 'I';	//not always to int
	elem[5] = to_type(accessor->comptype);

	return elem;
}

static std::string
decl_desc(const bufferinfo_array &bia) {
	std::string desc;
	for (const auto &bi : bia) {
		const std::string dd = decl_desc(bi.attribname, bi.accessor);
		if (!desc.empty()) {
			desc += "|";
		}
		desc += dd;
	}

	return desc;
}


static uint32_t
component_size(uint32_t componenttype) {
	switch (componenttype) {
	case ComponentType::BYTE:
	case ComponentType::UNSIGNED_BYTE:
		return 1;
	case ComponentType::SHORT:
	case ComponentType::UNSIGNED_SHORT:
		return 2;
	case ComponentType::UNSIGNED_INT:
	case ComponentType::FLOAT:
		return 4;
	default:
		assert(false);
		return 0;
	}
}

static uint32_t
elem_size(uint32_t elemtype, uint32_t componenttype) {
	assert(elemtype < sizeof(elem_type_mapper) / sizeof(elem_type_mapper[0]));

	return elem_type_mapper[elemtype].elem_count * component_size(componenttype);
}

static uint32_t 
buffer_elemsize(const bufferinfo_array &bia) {
	uint32_t sizebytes = 0;
	for (const auto &bi : bia) {
		const auto& accessor = bi.accessor;
		sizebytes += elem_size(accessor->type, accessor->comptype);
	}

	return sizebytes;
}


static const char*
buffer_data(const primitive::accessor &accessor, const char* bindata) {	
	const auto &bv = accessor.bv;
	const uint32_t offset = accessor.offset + bv.offset;
	return bindata + offset;
}

static void
create_buffer_desc(primitive &prim, buffer_desc &bufdesc) {
	auto& attributes = prim.attributes;	

	for (auto &attrib : attributes) {
		primitive::accessor &accessor = attrib.second;
		const auto &bv = accessor.bv;

		const auto itFound = std::find_if(bufdesc.begin(), bufdesc.end(), [=](const auto &v) { return v.first == bv.index;});
		if (itFound != bufdesc.end()) {
			itFound->second.push_back(bufferinfo{attrib.first, &accessor});
		} else {
			bufdesc.push_back(std::make_pair(bv.index, bufferinfo_array{ {attrib.first, &accessor} }));
		}
	}
}

static inline uint32_t
get_num_vertices(primitive &prim) {
	const uint32_t posattrib = 0;
	assert("POSITION" == attribname_mapper[posattrib].name);
	auto itpos = prim.attributes.find(posattrib);
	if (itpos != prim.attributes.end()) {
		const auto &pos_accessor = itpos->second;
		return pos_accessor.elemcount;
	}

	return 0;
}

static void
refine_accessors(buffer_desc &bd, primitive &prim) {
	for (auto &desc : bd) {
		const uint32_t bvidx = desc.first;
		bufferinfo_array& bia = desc.second;
	}
}

static std::string
write_primitive(const primitive &prim) {
	std::ostringstream oss;

	oss << (uint32_t)prim.attributes.size();

	for (const auto& attrib : prim.attributes) {
		oss << attrib.first;
		const primitive::accessor &acc = attrib.second;
		oss.write((const char*)&acc, sizeof(acc));
	}

	oss.write((const char*)&prim.indices, sizeof(prim.indices));

	return oss.str();
}

static int
lfetch_attribute_buffers(lua_State *L) {	
	primitive prim;
	fetch_primitive(L, 1, prim);

	const char* bindata = luaL_checkstring(L, 2);

	primitive newprim = prim;
	std::map<uint32_t, attribute_buffer>	attribbuffers;

	const uint32_t num_vertices = get_num_vertices(prim);

	for (const auto& attrib : newprim.attributes) {
		const uint32_t attribname = attrib.first;
		const primitive::accessor& acc = attrib.second;

		const uint32_t offset = acc.offset + acc.bv.offset;

		const char* srcbuf = bindata + offset;

		const uint32_t elemsize = elem_size(acc.type, acc.comptype);
		auto& abuffer = attribbuffers[attribname];

		abuffer.buffersize = elemsize * num_vertices;
		abuffer.data = new uint8_t[abuffer.buffersize];
		const uint32_t srcstride = acc.bv.stride != 0 ? acc.bv.stride : elemsize;

		uint8_t *data = abuffer.data;
		for (uint32_t iv = 0; iv < num_vertices; ++iv) {
			memcpy(data, srcbuf, elemsize);
			srcbuf += srcstride;
			data += elemsize;
		}

		primitive::accessor &newacc = newprim.attributes[attribname];
		newacc.offset = 0;
		newacc.bv.offset = 0;
		newacc.bv.length = abuffer.buffersize;
		newacc.bv.stride = elemsize;
	}

	const std::string primitive_serialize_data = write_primitive(newprim);
	lua_pushlstring(L, primitive_serialize_data.c_str(), primitive_serialize_data.size());

	lua_createtable(L, 0, (int)attribbuffers.size());
	for (const auto &ab : attribbuffers) {
		lua_createtable(L, 0, 2);
		lua_pushinteger(L, ab.second.buffersize);
		lua_setfield(L, -2, "buffersize");
		
		void *buf = lua_newuserdata(L, ab.second.buffersize);
		memcpy(buf, ab.second.data, ab.second.buffersize);
		lua_setfield(L, -2, "data");

		delete[] ab.second.data;
		ab.second.data;

		lua_setfield(L, -2, attribname_mapper[ab.first].name);	
	}

	return 2;
}

static inline void
fetch_attrib_buffer(lua_State *L, int idx, attribute_buffer &ab) {
	lua_getfield(L, idx, "sizebytes");
	ab.buffersize = (uint32_t)lua_tointeger(L, -1);
	lua_pop(L, 1);

	lua_getfield(L, idx, "data");
	ab.data = (uint8_t*)lua_touserdata(L, -1);
	lua_pop(L, 1);
}

extern void 
fetch_load_config(lua_State *L, int idx, load_config &config);

static inline uint32_t find_attrib_name(const std::string &elem) {
	const char et = elem[0];
	for (uint32_t attribname = 0;
		attribname < sizeof(attribname_mapper) / sizeof(attribname_mapper[0]);
		++attribname) {
		const auto& a = attribname_mapper[attribname];

		if (a.sname[0] == et) {
			return attribname;
		}
	}

	return (uint32_t)-1;
};

static bool
convert_buffer(const attribute_buffer &ab) {

	return false;
}

static int
lrearrange_buffers(lua_State *L) {	
	primitive prim;
	fetch_primitive(L, 1, prim);

	luaL_checktype(L, 2, LUA_TTABLE);
	luaL_checktype(L, 3, LUA_TTABLE);
	load_config cfg;
	fetch_load_config(L, 3, cfg);

	lua_pushnil(L);

	std::map<uint32_t, attribute_buffer>	attribute_buffers;

	while (lua_next(L, 2) != 0) {
		const uint32_t attribname = (uint32_t)luaL_checkinteger(L, -2);

		luaL_checktype(L, -1, LUA_TTABLE);
		attribute_buffer ab;
		fetch_attrib_buffer(L, -1, ab);

		attribute_buffers[attribname] = ab;
	}
	
	std::map<uint32_t, uint32_t>	attribmapper;

	std::vector<primitive::bufferview>	bufferviews(cfg.layouts.size());

	for (uint32_t ii = 0; ii < cfg.layouts.size(); ++ii) {
		const auto& layout = cfg.layouts[ii];

		auto elems = split_layout_elems(layout);

		attribute_buffer layout_ab = { 0 };
		std::vector<uint32_t> attribs;
		for (const auto &e : elems) {
			const uint32_t attribname = find_attrib_name(e);
			const auto &ab = attribute_buffers[attribname];
			layout_ab.buffersize += ab.buffersize;
			attribs.push_back(attribname);
		}

		auto& bv = bufferviews[ii];
		bv.index = ii;

		const auto& attributes = prim.attributes;
		layout_ab.data = new uint8_t[layout_ab.buffersize];
		uint8_t *data = layout_ab.data;
		uint32_t offset = 0;
		for (const auto &attribname : attribs) {
			const auto& ab = attribute_buffers[attribname];
			memcpy(data, ab.data, ab.buffersize);

			auto itFound = attributes.find(attribname);
			if (itFound == attributes.end()) {
				luaL_error(L, "could name found attribute in seri primitive data:%s", attribname_mapper[attribname].name);
			}

			const primitive::accessor& acc = itFound->second;
			attribmapper[attribname] = offset;
			offset += acc.bv.stride;
		}
	}

	return 3;
}

static int
lseriazlie_buffers(lua_State *L) {
	luaL_checktype(L, 1, LUA_TTABLE);

	std::map<uint32_t, uint32_t>	attriboffset;
	std::ostringstream oss;

	uint32_t offset = 0;
	lua_pushnil(L);
	while (lua_next(L, 1) != 0) {
		const uint32_t attribname = (uint32_t)luaL_checkinteger(L, -2);

		luaL_checktype(L, -1, LUA_TTABLE);
		attribute_buffer ab;
		fetch_attrib_buffer(L, -1, ab);
		
		oss.write((const char*)ab.data, ab.buffersize);
		attriboffset[attribname] = offset;
		offset += ab.buffersize;
	}

	const std::string buffer = oss.str();
	lua_pushlstring(L, buffer.c_str(), buffer.size());

	lua_createtable(L, 0, (int)attriboffset.size());
	for (const auto &p : attriboffset) {
		lua_pushinteger(L, p.second);
		lua_seti(L, -2, p.first);
	}

	return 1;
}

extern "C" {
	MC_EXPORT int
		luaopen_gltf_converter(lua_State *L) {
		const struct luaL_Reg libs[] = {	
			{ "fetch_buffers", lfetch_attribute_buffers, },
			{ "rearrange_buffers", lrearrange_buffers,},
			{ "seriazlie_buffers", lseriazlie_buffers},
			{ NULL, NULL },
		};
		luaL_newlib(L, libs);
		return 1;
	}
}