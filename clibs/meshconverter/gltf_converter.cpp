#include "common.h"
#include "meshdata.h"
#include "utils.h"

extern "C"
{
#include <lua.h>  
#include <lualib.h>
#include <lauxlib.h>
}

#include <string>
#include <vector>
#include <map>
#include <algorithm>
#include <sstream>

#include <cassert>

struct primitive {
	struct bufferview {		
		uint32_t byteOffset;
		uint32_t byteLength;
		uint32_t byteStride;
		uint32_t target;
	};

	struct accessor {
		uint32_t bufferView;
		uint32_t byteOffset;
		uint32_t componentType;
		uint32_t count;
		uint8_t normalized;
		uint8_t type;
		uint8_t padding[2];
		uint32_t minvalue_count;
		float minvalues[16];
		uint32_t maxvalue_count;
		float maxvalues[16];
	};

	
	std::map<uint32_t, uint32_t> attributes;	// need order
	uint32_t	indices;
	uint32_t	mode;

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

	{"WEIGHT_0", "w", 0},
	{"WEIGHT_1", "w", 1},

	{"JOINTS_0", "i", 0},
	{"JOINTS_1", "i", 1},
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

struct data_buffer {
	uint32_t buffersize;
	uint8_t *data;
	data_buffer()
		: buffersize(0)
		, data(nullptr){}

	data_buffer(data_buffer &&other) {
		data = other.data;
		buffersize = other.buffersize;
		other.data = nullptr;
		other.buffersize = 0;
	}

	~data_buffer() {
		if (data) {
			delete[]data;
			data = nullptr;
			buffersize = 0;
		}
	}
};

struct bufferinfo {
	uint32_t attribname;
	primitive::accessor *accessor;
};
using bufferinfo_array	= std::vector<bufferinfo>;
using bufferview_index	= uint32_t;
using buffer_desc		= std::vector<std::pair<bufferview_index, bufferinfo_array>>;
using attrib_buffers	= std::map<uint32_t, data_buffer>;

void
fetch_load_config(lua_State *L, int idx, load_config &config) {
	luaL_checktype(L, idx, LUA_TTABLE);

	verify(lua_getfield(L, idx, "layout") == LUA_TTABLE);
	const size_t numStreams = lua_rawlen(L, -1);
	config.layouts.resize(numStreams);
	for (size_t ii = 0; ii < numStreams; ++ii) {
		lua_geti(L, -1, ii + 1);
		std::string elem = lua_tostring(L, -1);
		config.layouts[ii] = refine_layouts(elem);
		lua_pop(L, 1);
	}
	lua_pop(L, 1);

	verify(LUA_TTABLE == lua_getfield(L, idx, "flags"));

	auto extract_boolean = [&](auto name, auto bit) {
		const int type = lua_getfield(L, -1, name);
		const bool need = type == LUA_TBOOLEAN ? lua_toboolean(L, -1) != 0 : false;
		if (need)
			config.flags |= bit;
		else
			config.flags &= ~bit;
		lua_pop(L, 1);
	};

	LayoutArray elems;
	for (const auto &layout : config.layouts) {
		auto ee = split_string(layout, '|');
		elems.insert(elems.end(), ee.begin(), ee.end());
	}

	if (std::find_if(std::begin(elems), std::end(elems), [](auto e) {return e[0] == 'n'; }) != std::end(elems))
		config.flags |= load_config::CreateNormal;

	if (std::find_if(std::begin(elems), std::end(elems), [](auto e) {return e[0] == 'T' || e[0] == 'b'; }) != std::end(elems))
		config.flags |= load_config::CreateTangent | load_config::CreateBitangent;

	extract_boolean("invert_normal", load_config::InvertNormal);
	extract_boolean("flip_u", load_config::FlipU);
	extract_boolean("flip_v", load_config::FlipV);

	extract_boolean("ib_32", load_config::IndexBuffer32Bit);
	extract_boolean("reset_root_pos", load_config::ResetRootPos);
}

static inline void
valid_primitive_data(const primitive &prim) {
	auto valid_accessor = [&prim](uint32_t accidx) {		
		assert(accidx < prim.accessors.size());

		const auto& acc = prim.accessors[accidx];
		assert(acc.bufferView < prim.bufferviews.size());
	};

	for (const auto&a : prim.attributes) {
		valid_accessor(a.second);
	}

	if (prim.indices != 0xffffffff) {
		valid_accessor(prim.indices);
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
	prim.mode = *uint32_data++;

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

//static std::string
//decl_desc(uint32_t attribname, const primitive::accessor *accessor) {
//	char elem[6];
//
//	auto to_type = [](auto v) {
//		switch (v) {
//		case ComponentType::BYTE:
//		case ComponentType::UNSIGNED_BYTE:
//			return 'u';
//		case ComponentType::SHORT:
//		case ComponentType::UNSIGNED_SHORT:
//			return 'i';
//		case ComponentType::FLOAT:
//			return 'f';
//		default:
//			return 'f';
//		}
//	};
//
//
//	assert(attribname < sizeof(attribname_mapper[0]) / sizeof(attribname_mapper[0]));
//
//	const auto& attrib = attribname_mapper[attribname];
//
//	elem[0] = attrib.sname[0];
//	elem[1] = '0' + accessor->count;
//	elem[2] = '0' + attrib.channel;
//	elem[3] = accessor->normalized ? 'n' : 'N';
//	elem[4] = 'I';	//not always to int
//	elem[5] = to_type(accessor->componentType);
//
//	return elem;
//}

//static std::string
//decl_desc(const bufferinfo_array &bia) {
//	std::string desc;
//	for (const auto &bi : bia) {
//		const std::string dd = decl_desc(bi.attribname, bi.accessor);
//		if (!desc.empty()) {
//			desc += "|";
//		}
//		desc += dd;
//	}
//
//	return desc;
//}


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

//static uint32_t 
//buffer_elemsize(const bufferinfo_array &bia) {
//	uint32_t sizebytes = 0;
//	for (const auto &bi : bia) {
//		const auto& accessor = bi.accessor;
//		sizebytes += elem_size(accessor->type, accessor->componentType);
//	}
//
//	return sizebytes;
//}

static inline uint32_t
get_num_vertices(const primitive &prim) {
	const uint32_t posattrib = 0;
	assert(std::string("POSITION") == std::string(attribname_mapper[posattrib].name));
	auto itpos = prim.attributes.find(posattrib);
	if (itpos != prim.attributes.end()) {
		const auto &accidx = itpos->second;
		return prim.accessors[accidx].count;
	}

	return 0;
}

static std::string
serialize_primitive(const primitive &prim) {
	std::ostringstream oss;

	auto write_u32 = [&oss](uint32_t v) {		
		oss.write((const char*)&v, sizeof(uint32_t));
	};

	write_u32((uint32_t)prim.attributes.size());
	for (const auto& attrib : prim.attributes) {
		write_u32(attrib.first);
		write_u32(attrib.second);		
	}

	write_u32(prim.indices);
	write_u32(prim.mode);

	write_u32((uint32_t)prim.accessors.size());
	
	oss.write((const char*)(&prim.accessors[0]), sizeof(primitive::accessor) * prim.accessors.size());

	write_u32((uint32_t)prim.bufferviews.size());
	oss.write((const char*)(&prim.bufferviews[0]), sizeof(primitive::bufferview) * prim.bufferviews.size());

	return oss.str();
}

static uint32_t
fetch_buffer(const primitive &prim, const primitive::accessor &acc, const char* bindata, 
	uint32_t num_elem, data_buffer &abuffer) {
	const primitive::bufferview& bv = prim.bufferviews[acc.bufferView];
	const uint32_t offset = acc.byteOffset + bv.byteOffset;
	const char* srcbuf = bindata + offset;

	const uint32_t elemsize = elem_size(acc.type, acc.componentType);

	abuffer.buffersize = elemsize * num_elem;
	abuffer.data = new uint8_t[abuffer.buffersize];

	if (bv.byteStride != 0) {
		const uint32_t srcstride = bv.byteStride;
		uint8_t *data = abuffer.data;
		for (uint32_t iv = 0; iv < num_elem; ++iv) {
			memcpy(data, srcbuf, elemsize);
			srcbuf += srcstride;
			data += elemsize;
		}
	} else {
		memcpy(abuffer.data, srcbuf, abuffer.buffersize);
	}

	return abuffer.buffersize;
}

static void
fetch_attribute_buffers(const primitive &prim, const char* bindata, attrib_buffers &abuffers) {
	const uint32_t num_vertices = get_num_vertices(prim);

	for (const auto& attrib : prim.attributes) {
		const uint32_t attribname = attrib.first;
		const primitive::accessor& acc = prim.accessors[attrib.second];

		auto& abuffer = abuffers[attribname];
		fetch_buffer(prim, acc, bindata, num_vertices, abuffer);
	}
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
}

static void
rearrange_indices_buffer(primitive &prim, uint32_t binaryoffset, const char* bindata, 
	std::vector<primitive::bufferview> &new_bvs, std::vector<data_buffer> &newbuffers) {

	if (prim.indices != 0xffffffff) {
		auto& acc = prim.accessors[prim.indices];
		newbuffers.push_back(data_buffer());
		fetch_buffer(prim, acc, bindata, acc.count, newbuffers.back());

		primitive::bufferview bv = prim.bufferviews[acc.bufferView];
		bv.byteOffset = binaryoffset;
		acc.bufferView = (uint32_t)new_bvs.size();
		new_bvs.push_back(bv);
	}
}

static uint32_t
rearrange_buffers(
	const attrib_buffers& abuffers, 
	const load_config& cfg, 	
	primitive& prim, 
	std::vector<primitive::bufferview>&	newbufferviews,
	std::vector<data_buffer> &newbuffers) {

	uint32_t binary_offset = 0;
	newbufferviews.resize(cfg.layouts.size());
	newbuffers.resize(cfg.layouts.size());

	const auto& attributes = prim.attributes;
	std::map<uint32_t, uint32_t>	new_attributes;
	for (uint32_t bvidx = 0; bvidx < cfg.layouts.size(); ++bvidx) {
		const auto& layout = cfg.layouts[bvidx];

		auto elems = split_layout_elems(layout);

		auto &newbuf = newbuffers[bvidx];
		struct attrib_info {
			uint32_t name;
			uint32_t elemsize;
			uint8_t *data;
		};
		std::vector<attrib_info> attribs;

		uint32_t stride = 0;
		for (const auto &e : elems) {
			const uint32_t attribname = find_attrib_name(e);
			auto itAB = abuffers.find(attribname);
			if (itAB != abuffers.end()) {
				const auto& ab = itAB->second;
				newbuf.buffersize += ab.buffersize;

				auto itAttrib = attributes.find(attribname);
				if (itAttrib == attributes.end()) {
					assert("could not found attribute in seri primitive data");
				}

				const uint32_t accidx = itAttrib->second;
				new_attributes[attribname] = accidx;
				primitive::accessor& acc = prim.accessors[accidx];
				const uint32_t elemsize = elem_size(acc.type, acc.componentType);

				acc.byteOffset = stride;
				acc.bufferView = bvidx;
				stride += elemsize;

				attribs.push_back(attrib_info{attribname, elemsize, ab.data});
			} else {
				assert("not found attribute need create new buffer or error this");
			}
		}

		auto &newbv = newbufferviews[bvidx];
		newbv.byteOffset = binary_offset;
		newbv.byteLength = newbuf.buffersize;
		newbv.byteStride	= stride;
		newbv.target	= target_type::ARRAY_BUFFER;		

		assert(newbuf.data == nullptr);
		newbuf.data = new uint8_t[newbuf.buffersize];
		
		const uint32_t num_vertices = get_num_vertices(prim);

		for (uint32_t ii = 0; ii < num_vertices; ++ii) {
			uint8_t *vertex = newbuf.data + ii * stride;
			for (const auto &ainfo : attribs) {
				const uint8_t *srcdata = ainfo.data;
				memcpy(vertex, srcdata + ii * ainfo.elemsize, ainfo.elemsize);
				vertex += ainfo.elemsize;
			}
		}

		binary_offset += newbuf.buffersize;
	}
	
	std::swap(prim.attributes, new_attributes);
	return binary_offset;
}

static std::string
serialize_buffers(const std::vector<data_buffer> &buffers) {
	std::ostringstream oss;
	for (const auto &b : buffers) {
		oss.write((const char*)b.data, b.buffersize);
	}

	return oss.str();
}

static void
create_normal(const attrib_buffers &buffers, const data_buffer&indicesbuffer, const primitive& prim, data_buffer &buffer) {
	primitive::accessor normalaccessor;
	normalaccessor.bufferView = -1;
	normalaccessor.byteOffset = 0;
	normalaccessor.componentType = ComponentType::FLOAT;
	normalaccessor.type = 3;
	
	normalaccessor.count = get_num_vertices(prim);
	normalaccessor.normalized = true;

	normalaccessor.maxvalue_count = 0;
	normalaccessor.minvalue_count = 0;


	for (uint32_t ii = 0; ii < normalaccessor.count; ++ii) {

	}
}

static void
create_tangent_bitangent(
	const char* bindata, 
	const primitive &prim, 
	data_buffer &tangentbuffer, 
	data_buffer &bitangentbuffer) {

}

static void
check_and_generate_new_attribute(const load_config &cfg, const char* bindata, primitive &prim) {
	if (cfg.NeedCreateNormal()) {

	}

	if (cfg.NeedCreateTangentSpaceData()) {

	}
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

	std::vector<data_buffer> newbuffers;
	std::vector<primitive::bufferview>	newbufferviews;
	const uint32_t binary_offset = rearrange_buffers(abuffers, cfg, prim, newbufferviews, newbuffers);
	rearrange_indices_buffer(prim, binary_offset, bindata, newbufferviews, newbuffers);

	prim.bufferviews.swap(newbufferviews);

	const std::string seri_prim = serialize_primitive(prim);
	const std::string newbin = serialize_buffers(newbuffers);

	lua_pushlstring(L, seri_prim.c_str(), seri_prim.size());
	lua_pushlstring(L, newbin.c_str(), newbin.size());

	return 2;
}

extern "C" {
	MC_EXPORT int
		luaopen_meshconverter_gltf(lua_State *L) {
		const struct luaL_Reg libs[] = {	
			{ "convert_buffers", lconvert_buffers, },
			{ NULL, NULL },
		};
		luaL_newlib(L, libs);
		return 1;
	}
}