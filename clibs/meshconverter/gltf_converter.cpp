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
		uint32_t offset;
		uint32_t length;
		uint32_t stride;
		uint32_t target;
	};

	struct accessor {
		uint32_t bufferview;
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

	
	std::map<uint32_t, uint32_t> attributes;	// need order
	uint32_t	indices;

	std::vector<accessor> accessors;
	std::vector<bufferview> bufferviews;
};

enum target_type {
	ARRAY_BUFFER			= 34962,
	ELEMENT_ARRAY_BUFFER	= 34963,
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
using bufferinfo_array	= std::vector<bufferinfo>;
using bufferview_index	= uint32_t;
using buffer_desc		= std::vector<std::pair<bufferview_index, bufferinfo_array>>;
using attrib_buffers	= std::map<uint32_t, attribute_buffer>;

extern void
fetch_load_config(lua_State *L, int idx, load_config &config);

static inline void
valid_primitive_data(const primitive &prim) {
	for (const auto&a : prim.attributes) {
		const uint32_t accidx = a.second;
		assert(accidx < prim.accessors.size());

		const auto& acc = prim.accessors[accidx];
		assert(acc.bufferview < prim.bufferviews.size());
	}
}

static bool 
fetch_primitive(lua_State *L, int index,  primitive &prim) {
	size_t size_bytes = 0;
	const char* serializedata = luaL_checklstring(L, index, &size_bytes);

	const uint32_t numattrib = *((uint32_t*)serializedata);	

	// read attributes
	const uint32_t* uint32_data = (const uint32_t*)(serializedata + sizeof(uint32_t));
	for (uint32_t ii = 0; ii < numattrib; ++ii) {		
		const uint32_t attribname	= *uint32_data++;
		const uint32_t accidx		= *uint32_data++;		
		prim.attributes[attribname] = accidx;
	}

	prim.indices = *uint32_data++;

	// read accessors
	const uint32_t num_accessors = *uint32_data++;
	prim.accessors.resize(num_accessors);

	const uint32_t accessors_sizebytes = sizeof(primitive::accessor) * num_accessors;
	memcpy(&prim.accessors[0], uint32_data, accessors_sizebytes);

	uint32_data = (const uint32_t*)((const uint8_t*)uint32_data + accessors_sizebytes);
	const uint32_t num_bufferviews = *uint32_data++;
	prim.bufferviews.resize(num_bufferviews);
	memcpy(&prim.bufferviews[0], uint32_data, sizeof(primitive::bufferview) * num_bufferviews);

#ifdef _DEBUG
	valid_primitive_data(prim);
#endif // _DEBUG

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

static inline uint32_t
get_num_vertices(const primitive &prim) {
	const uint32_t posattrib = 0;
	assert("POSITION" == attribname_mapper[posattrib].name);
	auto itpos = prim.attributes.find(posattrib);
	if (itpos != prim.attributes.end()) {
		const auto &accidx = itpos->second;
		return prim.accessors[accidx].elemcount;
	}

	return 0;
}

static std::string
serialize_primitive(const primitive &prim) {
	std::ostringstream oss;

	oss << (uint32_t)prim.attributes.size();

	for (const auto& attrib : prim.attributes) {
		oss << attrib.first << attrib.second;		
	}

	oss << prim.indices;

	oss << (uint32_t)prim.accessors.size();
	oss.write((const char*)(&prim.accessors[0]), sizeof(primitive::accessor) * prim.accessors.size());

	oss << (uint32_t)prim.bufferviews.size();
	oss.write((const char*)(&prim.bufferviews[0]), sizeof(primitive::bufferview) * prim.bufferviews.size());

	return oss.str();
}

static void
fetch_attribute_buffers(const primitive &prim, const char* bindata, attrib_buffers &abuffers) {
	const uint32_t num_vertices = get_num_vertices(prim);

	for (const auto& attrib : prim.attributes) {
		const uint32_t attribname = attrib.first;
		const primitive::accessor& acc = prim.accessors[attrib.second];
		const primitive::bufferview& bv = prim.bufferviews[acc.bufferview];

		const uint32_t offset = acc.offset + bv.offset;

		const char* srcbuf = bindata + offset;

		const uint32_t elemsize = elem_size(acc.type, acc.comptype);
		auto& abuffer = abuffers[attribname];

		abuffer.buffersize = elemsize * num_vertices;
		abuffer.data = new uint8_t[abuffer.buffersize];
		const uint32_t srcstride = bv.stride != 0 ? bv.stride : elemsize;

		uint8_t *data = abuffer.data;
		for (uint32_t iv = 0; iv < num_vertices; ++iv) {
			memcpy(data, srcbuf, elemsize);
			srcbuf += srcstride;
			data += elemsize;
		}
	}
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

static inline uint32_t 
find_attrib_name(const std::string &elem) {
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

static uint32_t
calc_stride(const primitive &prim, const std::vector<uint32_t> &attribs) {
	uint32_t stride = 0;
	for (uint32_t a : attribs) {
		auto it = prim.attributes.find(a);
		assert(it != prim.attributes.end());
		const uint32_t accidx = it->second;
		const auto& accessor = prim.accessors[accidx];
		
		stride += elem_size(accessor.type, accessor.comptype);
	}

	return stride;
}

static void
rearrange_buffers(
	const attrib_buffers& abuffers, 
	const load_config& cfg, 
	primitive& prim, 
	std::vector<attribute_buffer> &newbuffers) {

	std::vector<primitive::bufferview>	newbufferviews(cfg.layouts.size());
	uint32_t binary_offset = 0;

	newbuffers.resize(cfg.layouts.size());

	for (uint32_t ii = 0; ii < cfg.layouts.size(); ++ii) {
		const auto& layout = cfg.layouts[ii];

		auto elems = split_layout_elems(layout);

		auto &newbuf = newbuffers[ii];
		std::vector<uint32_t> attribs;
		for (const auto &e : elems) {
			const uint32_t attribname = find_attrib_name(e);
			auto it = abuffers.find(attribname);
			if (it != abuffers.end()) {
				const auto& ab = it->second;
				newbuf.buffersize += ab.buffersize;
				attribs.push_back(attribname);
			} else {
				assert("not found attribute need create new buffer or error this");
			}
		}

		auto &newbv = newbufferviews[ii];
		newbv.offset = binary_offset;
		newbv.length = newbuf.buffersize;
		newbv.stride = calc_stride(prim, attribs);
		newbv.target = target_type::ARRAY_BUFFER;		

		const auto& attributes = prim.attributes;
		newbuf.data = new uint8_t[newbuf.buffersize];
		uint8_t *data = newbuf.data;
		uint32_t attriboffset = 0;

		for (const auto &attribname : attribs) {
			auto it = abuffers.find(attribname);
			assert(it != abuffers.end());
			const auto& ab = it->second;
			memcpy(data, ab.data, ab.buffersize);

			auto itFound = attributes.find(attribname);
			if (itFound == attributes.end()) {
				assert("could name found attribute in seri primitive data");				
			}

			primitive::accessor& acc = prim.accessors[itFound->second];
			const uint32_t elemsize = elem_size(acc.type, acc.elemcount);

			acc.offset = attriboffset;
			attriboffset += elemsize;
		}

		binary_offset = newbuf.buffersize;
	}

	prim.bufferviews.swap(newbufferviews);
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

static std::string
serialize_buffers(const std::vector<attribute_buffer> &buffers) {
	std::ostringstream oss;
	for (const auto &b : buffers) {
		oss.write((const char*)b.data, b.buffersize);
	}

	return oss.str();
}

static int
lconvert_buffers(lua_State *L) {
	primitive prim;
	fetch_primitive(L, 1, prim);

	const char* bindata = luaL_checkstring(L, 2);

	load_config cfg;
	fetch_load_config(L, 3, cfg);

	attrib_buffers abuffers;
	fetch_attribute_buffers(prim, bindata, abuffers);

	std::vector<attribute_buffer> newbuffers;
	rearrange_buffers(abuffers, cfg, prim, newbuffers);

	const std::string seri_prim = serialize_primitive(prim);
	const std::string newbin = serialize_buffers(newbuffers);

	lua_pushlstring(L, seri_prim.c_str(), seri_prim.size());
	lua_pushlstring(L, newbin.c_str(), newbin.size());

	return 2;
}

extern "C" {
	MC_EXPORT int
		luaopen_gltf_converter(lua_State *L) {
		const struct luaL_Reg libs[] = {	
			{ "convert_buffers", lconvert_buffers, },
			{ NULL, NULL },
		};
		luaL_newlib(L, libs);
		return 1;
	}
}