#include "meshdata.h"

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

//c std
#include <cassert>

//void WriteMaterialToLua(lua_State *L, const aiScene* scene) {
//	unsigned mat_count = scene->mNumMaterials;
//	for (unsigned i = 0; i < mat_count; ++i) {
//		aiMaterial* mat = scene->mMaterials[i];
//
//		lua_newtable(L);
//
//		//{@	texture_path = {}
//		{
//			struct TexturePathInfo {
//				const char* name;
//				aiTextureType type;
//				uint32_t idx;
//			};
//
//			TexturePathInfo typepaths[] = {
//				{ "diffuse", aiTextureType_DIFFUSE, 0, },
//				{ "ambient", aiTextureType_AMBIENT, 0, },
//				{ "specular", aiTextureType_SPECULAR, 0, },
//				{ "normals", aiTextureType_NORMALS, 0, },
//				{ "shininess", aiTextureType_SHININESS, 0, },
//				{ "lightmap", aiTextureType_LIGHTMAP, 0, },
//			};
//
//			lua_createtable(L, 0, sizeof(typepaths) / sizeof(typepaths[0]));
//
//			for (const auto &info : typepaths) {
//				aiString path;
//				if (AI_SUCCESS == mat->Get(_AI_MATKEY_TEXTURE_BASE, info.type, info.idx, path)) {
//					lua_pushstring(L, path.C_Str());
//					lua_setfield(L, -2, info.name);
//				}
//			}
//
//			lua_setfield(L, -2, "texture_path");
//		}
//		//@}
//
//
//		aiString name;
//		if (AI_SUCCESS == mat->Get(AI_MATKEY_NAME, name)){
//			lua_pushstring(L, name.C_Str());
//			lua_setfield(L, -2, "name");
//		}
//
//		//{@	material color
//		{
//			auto push_color = [L](const char* name, const aiColor3D &color) {
//				lua_createtable(L, 0, 3);
//				const char* elemnames[] = { "r", "g", "b" };
//				for (uint32_t ii = 0; ii < 3; ++ii) {
//					lua_pushnumber(L, color[ii]);
//					lua_setfield(L, -2, elemnames[ii]);
//				}
//
//				lua_setfield(L, -2, name);
//			};
//
//			struct MatKeys { const char* k; int i, j; const char *name; };
//			MatKeys keys[] = {
//				{ AI_MATKEY_COLOR_AMBIENT, "ambient" },
//			{ AI_MATKEY_COLOR_DIFFUSE, "diffuse" },
//			{ AI_MATKEY_COLOR_SPECULAR, "specular" },
//			};
//
//			for (const auto &k : keys) {
//				aiColor3D color;
//				if (AI_SUCCESS == mat->Get(k.k, k.i, k.j, color)) {
//					push_color(k.name, color);
//				}
//			}
//		}
//		//@}
//
//
//		lua_seti(L, -2, i + 1);
//	}
//}

void LoadMaterials(const aiScene* scene, std::vector<mesh_material_data> &materials) {	
	materials.resize(scene->mNumMaterials);
	for (uint32_t i = 0; i < scene->mNumMaterials; ++i) {
		aiMaterial* mat = scene->mMaterials[i];
		{
			std::pair<const char*, aiTextureType> typepaths[] = {
				{ "diffuse", aiTextureType_DIFFUSE, },
				{ "ambient", aiTextureType_AMBIENT, },
				{ "specular", aiTextureType_SPECULAR, },
				{ "normals", aiTextureType_NORMALS, },
				{ "shininess", aiTextureType_SHININESS, },
				{ "lightmap", aiTextureType_LIGHTMAP, },
			};

			auto &textures = materials[i].textures;
			for (const auto &info : typepaths) {
				aiString path;
				const uint32_t num = mat->GetTextureCount(info.second);
				if (num > 1) {
					printf("texture type : %s, have more than one textures, num is = %d, we only get the first texture\n", info.first, num);
				}
				if (AI_SUCCESS == mat->Get(_AI_MATKEY_TEXTURE_BASE, info.second, 0, path))
					textures[info.first] = path.C_Str();
			}
		}
		//@}


		aiString name;
		if (AI_SUCCESS == mat->Get(AI_MATKEY_NAME, name)) {
			materials[i].name = name.C_Str();
		}

		//{@	material color
		{
			struct MatKeys { const char* k; int i, j; const char *name; };
			MatKeys keys[] = {
				{ AI_MATKEY_COLOR_AMBIENT, "ambient" },
				{ AI_MATKEY_COLOR_DIFFUSE, "diffuse" },
				{ AI_MATKEY_COLOR_SPECULAR, "specular" },
			};

			auto &colors = materials[i].colors;
			for (const auto &k : keys) {
				aiColor3D color;
				if (AI_SUCCESS == mat->Get(k.k, k.i, k.j, color))
					colors[k.name] = *((glm::vec3*)(&color.r));
			}
		}
		//@}
	}
}

//static void push_aabb(lua_State *L, const AABB &aabb, int32_t tblidx) {
//	lua_createtable(L, 6, 0);
//	const ai_real *p = &aabb.min.x;
//	for (uint32_t ii = 0; ii < 6; ++ii) {
//		lua_pushnumber(L, *p++);
//		lua_seti(L, -2, ii + 1);
//	}
//	lua_setfield(L, tblidx, "aabb");
//}
//
//static void push_sphere(lua_State *L, const BoundingSphere &sphere, int32_t tblidx) {
//	lua_createtable(L, 4, 0);
//	const ai_real *p1 = &sphere.center.x;
//	for (uint32_t ii = 0; ii < 4; ++ii) {
//		lua_pushnumber(L, *p1++);
//		lua_seti(L, -2, ii + 1);
//	}
//
//	lua_setfield(L, tblidx, "sphere");
//}
//
//static void push_sphere(lua_State *L, const AABB &aabb, int32_t tblidx) {
//	BoundingSphere sphere; sphere.Init(aabb);
//	push_sphere(L, sphere, tblidx);
//}

using MeshArray = std::vector<aiMesh*>;
using MeshMaterialArray = std::vector<MeshArray>;


struct load_config {
	load_config()
		: layout("p3|n|T|b|t20|c30")
		, flags(0) {}

	bool NeedCreateNormal() const {
		return flags & CreateNormal;
	}

	bool NeedCreateTangentSpaceData() const {
		return flags & (CreateTangent | CreateBitangent);
	}

	bool NeedFlipUV()const {
		return flags & FlipUV;
	}

	std::string layout;

	enum {
		CreateNormal = 0x00000001,
		CreateTangent = 0x00000002,
		CreateBitangent = 0x00000004,

		InvertNormal = 0x00000010,
		FlipUV = 0x00000020,
		IndexBuffer32Bit = 0x00000040,

	};
	uint32_t flags;
};

static void
SeparateMeshByMaterialID(const aiScene *scene, MeshMaterialArray &mm) {
	mm.resize(scene->mNumMaterials);
	for (uint32_t ii = 0; ii < scene->mNumMaterials; ++ii) {
		auto mesh = scene->mMeshes[ii];
		MeshArray &meshes = mm[mesh->mMaterialIndex];
		meshes.push_back(mesh);
	}
}

static inline std::vector<std::string>
Split(const std::string &ss, char delim) {
	std::istringstream iss(ss);
	std::vector<std::string> vv;
	std::string elem;
	while (std::getline(iss, elem, delim)) {
		vv.push_back(elem);
	}

	return vv;
}

// only valid in array of struct
static std::string
CreateVertexLayout(aiMesh *mesh, const std::string &vertexElemNeeded) {
	auto elems = Split(vertexElemNeeded, '|');

	std::string ss;
	auto add_elem = [&ss, &elems](const auto &e) {
		auto it = std::find_if(elems.begin(), elems.end(), [e](auto ename) {
			const auto &name = std::get<0>(e);

			if (ename.length() == 3 && name.length() == 3) {
				return ename[0] == name[0] && ename[2] == name[2];
			}

			return (ename[0] == name[0]);
		});
		auto op = std::get<2>(e);
		if (it != elems.end() && op()) {
			if (!ss.empty())
				ss += '|';

			std::string name = *it;
			if (name.length() < 2) {
				const uint8_t default_count = std::get<1>(e);
				name.append(std::to_string(default_count));
			}
			ss += name;
		}
	};

	std::vector<std::tuple<std::string, uint8_t, std::function<bool()>>>	check_array = {
		std::make_tuple("p", 3, [mesh]() {return mesh->HasPositions(); }),
		std::make_tuple("n", 3, [mesh]() {return mesh->HasNormals(); }),
		std::make_tuple("T", 3, [mesh]() {return mesh->HasTangentsAndBitangents(); }),
		std::make_tuple("b", 3, [mesh]() {return mesh->HasTangentsAndBitangents(); }),
	};

	for (const auto &p : check_array) {
		add_elem(p);
	}

	auto add_array_elem = [&](const std::string &basename, uint8_t default_count, auto check_array) {
		for (auto ii = 0; ii < 4; ++ii) {
			const std::string n = basename + std::to_string(ii);
			add_elem(std::make_tuple(n, default_count, [ii, check_array]() { return check_array(ii); }));
		}
	};

	add_array_elem("t", 3, [mesh](uint32_t idx) {return mesh->HasTextureCoords(idx); });
	add_array_elem("c", 4, [mesh](uint32_t idx) {return mesh->HasVertexColors(idx); });

	return ss;
}

using VertexElemMap = std::unordered_map<std::string, std::function<float *(const aiMesh *mesh, uint32_t idx)> >;

VertexElemMap g_elemMap;

static void
InitElemMap() {
	if (!g_elemMap.empty())
		return;

	g_elemMap["p"] = [](const aiMesh *mesh, uint32_t idx) {return &mesh->mVertices[idx].x; };
	g_elemMap["n"] = [](const aiMesh *mesh, uint32_t idx) {return &mesh->mNormals[idx].x; };
	g_elemMap["T"] = [](const aiMesh *mesh, uint32_t idx) {return &mesh->mTangents[idx].x; };
	g_elemMap["b"] = [](const aiMesh *mesh, uint32_t idx) {return &mesh->mBitangents[idx].x; };

	auto add_array_type = [](auto basename, auto totalnum, auto create_op) {
		for (int ii = 0; ii < totalnum; ++ii) {
			std::string name = basename + std::to_string(ii);
			g_elemMap[name] = create_op(ii);
		}
	};

	struct TexCoordValuePtrOp {
		TexCoordValuePtrOp(uint32_t ii) : texIdx(ii) {}
		uint32_t texIdx;
		float * operator()(const aiMesh *mesh, uint32_t idx) {
			return &(mesh->mTextureCoords[texIdx][idx].x);
		}
	};

	add_array_type("t", 4, [](auto ii) { return TexCoordValuePtrOp(ii); });


	struct ColorValuePtrOp {
		ColorValuePtrOp(uint32_t ii) : colorIdx(ii) {}
		uint32_t colorIdx;
		float * operator()(const aiMesh *mesh, uint32_t idx) {
			return &(mesh->mColors[colorIdx][idx].r);
		}
	};

	add_array_type("c", 4, [](auto ii) { return ColorValuePtrOp(ii); });

};

static inline void
extract_layout_elem_info(const std::string &le, std::string &type, uint8_t &count) {
	type += le[0];
	type += le[1];
	
	count = static_cast<uint8_t>(std::stoi(le.substr(1, 1)));
}

static size_t
CalcVertexSize(const std::string &layout) {
	size_t elemSizeInBytes = 0;
	auto vv = Split(layout, '|');

	for (auto v : vv) {
		const std::string type = v.substr(0, 1);
		const uint8_t elemCount = static_cast<uint8_t>(std::stoi(v.substr(1, 1)));

		elemSizeInBytes += elemCount * sizeof(float);
	}

	return elemSizeInBytes;
};

static void
CalcBufferSize(const MeshArray &meshes,
	const std::string &layout,
	const load_config &config,
	size_t &vertexSizeInBytes, size_t &indexSizeInBytes, size_t &indexElemSizeInBytes) {
	if (meshes.empty())
		return;

	const size_t elemSizeInBytes = CalcVertexSize(layout);

	size_t numVertices = 0, numIndices = 0;
	for (auto mesh : meshes) {
		numVertices += mesh->mNumVertices;
		for (uint32_t ii = 0; ii < mesh->mNumFaces; ++ii) {
			auto face = mesh->mFaces[ii];
			numIndices += face.mNumIndices;
		}
	}

	vertexSizeInBytes = numVertices * elemSizeInBytes;

	indexElemSizeInBytes = sizeof(uint16_t);
	if (numVertices > uint16_t(-1)) {
		indexElemSizeInBytes = sizeof(uint32_t);
	} else {
		indexElemSizeInBytes = ((config.flags & load_config::IndexBuffer32Bit) ? sizeof(uint32_t) : sizeof(uint16_t));
	}

	indexSizeInBytes = numIndices * indexElemSizeInBytes;
}

static void
CopyMeshVertices(const aiMesh *mesh, const std::string &layout, const load_config &config, float * &vertices) {
	auto vv = Split(layout, '|');

	for (uint32_t ii = 0; ii < mesh->mNumVertices; ++ii) {
		for (auto v : vv) {
			assert(v.length() >= 2);
			std::string type;
			uint8_t elemCount;
			extract_layout_elem_info(v, type, elemCount);

			const auto &value_ptr = g_elemMap[type];
			const float * ptr = value_ptr(mesh, ii);

			memcpy(vertices, ptr, elemCount * sizeof(float));
			vertices += elemCount;
		}
	}

}

static size_t
CopyMeshIndices(const aiMesh *mesh, const load_config &config, uint8_t* &indices) {
	size_t numIndices = 0;
	for (uint32_t ii = 0; ii < mesh->mNumFaces; ++ii) {
		const auto& face = mesh->mFaces[ii];
		if (config.flags & load_config::IndexBuffer32Bit) {
			const size_t sizeInBytes = face.mNumIndices * sizeof(uint32_t);
			memcpy(indices, face.mIndices, sizeInBytes);
			indices += sizeInBytes;
		} else {
			const size_t sizeInBytes = face.mNumIndices * sizeof(uint16_t);
			uint16_t *uint16Indices = reinterpret_cast<uint16_t*>(indices);
			for (uint32_t ii = 0; ii < face.mNumIndices; ++ii) {
				*uint16Indices++ = static_cast<uint16_t>(face.mIndices[ii]);
			}

			indices += sizeInBytes;
		}

		numIndices += face.mNumIndices;
	}

	return numIndices;
}

static bool
FindTransform(const aiScene *scene, const aiNode *node, const aiMesh *mesh, aiMatrix4x4 &mat) {
	if (node) {
		for (uint32_t ii = 0; ii < node->mNumMeshes; ++ii) {
			const uint32_t meshIdx = node->mMeshes[ii];
			if (scene->mMeshes[meshIdx] == mesh) {
				for (const aiNode *parent = node; parent; parent = parent->mParent) {
					mat *= parent->mTransformation;
				}
				return true;
			}
		}

		for (uint32_t ii = 0; ii < node->mNumChildren; ++ii) {
			if (FindTransform(scene, node->mChildren[ii], mesh, mat))
				return true;
		}
	}

	return false;
}

//static std::pair<std::string, bgfx::AttribType::Enum>
//attrib_type_name_pairs[bgfx::AttribType::Count] = {
//	{ "UINT8", bgfx::AttribType::Uint8 },
//	{ "UINT10", bgfx::AttribType::Uint10 },
//	{ "INT16", bgfx::AttribType::Int16 },
//	{ "HALF", bgfx::AttribType::Half },
//	{ "FLOAT", bgfx::AttribType::Float },
//};
//
//static inline bgfx::AttribType::Enum
//what_elem_type(const std::string &n) {
//	for (auto &pp : attrib_type_name_pairs) {
//		if (pp.first == n)
//			return pp.second;
//	}
//
//	return bgfx::AttribType::Count;
//}

#if defined(DISABLE_ASSERTS)
# define verify(expr) ((void)(expr))
#else
# define verify(expr) assert(expr)
#endif	

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

static void
LoadMeshes(const aiScene *scene, const load_config& config, mesh_data &md) {
	MeshMaterialArray mm;
	SeparateMeshByMaterialID(scene, mm);

	md.groups.resize(mm.size());

	for (size_t ii = 0; ii < mm.size(); ++ii){
		const auto &meshes = mm[ii];
		if (meshes.empty())
			continue;
		auto &group = md.groups[ii];
		group.vb_layout = CreateVertexLayout(meshes.back(), config.layout);

		size_t vertexSizeInBytes = 0, indexSizeInBytes = 0, indexElemSizeInBytes = 0;
		CalcBufferSize(meshes, group.vb_layout, config, vertexSizeInBytes, indexSizeInBytes, indexElemSizeInBytes);

		group.vbraw = new uint8_t[vertexSizeInBytes];
		group.num_vertices = vertexSizeInBytes / CalcVertexSize(group.vb_layout);

		group.ibraw = new uint8_t[indexSizeInBytes];
		group.num_indices = indexSizeInBytes / indexElemSizeInBytes;
		group.ib_format = indexElemSizeInBytes == 4 ? 32 : 16;
	
		group.primitives.resize(meshes.size());

		float *vertices = (float*)group.vbraw;
		uint8_t *indices = group.ibraw;
	
		size_t startVB = 0, startIB = 0;
		for (size_t jj = 0; jj < meshes.size(); ++jj) {
			const aiMesh *mesh = meshes[jj];

			auto &primitive = group.primitives[jj];
			
			aiMatrix4x4 transform;
			FindTransform(scene, scene->mRootNode, mesh, transform);
			//primitive.transform = *((glm::mat4x4*)(&transform));
			// avoid memory align bug
			for (uint32_t icol = 0; icol < 4; ++icol) {
				auto &col = primitive.transform[icol];
				const auto* src = transform[icol];
				for (uint32_t irow = 0; irow < 4; ++irow)
					col[irow] = src[irow];
			}
			
			primitive.name = mesh->mName.C_Str();
			primitive.material_idx = mesh->mMaterialIndex;

			// vertices			
			CopyMeshVertices(mesh, group.vb_layout, config, vertices);

			primitive.start_vertex = startVB;
			primitive.num_vertices = mesh->mNumVertices;
			
			startVB += mesh->mNumVertices;

			// indices
			size_t meshIndicesCount = CopyMeshIndices(mesh, config, indices);
			primitive.start_index = startIB;			
			primitive.num_indices = meshIndicesCount;
			
			primitive.bounding.Init((glm::vec3*)(mesh->mVertices), mesh->mNumVertices);
			
			group.bounding.Merge(primitive.bounding);
		}

		md.bounding.Merge(group.bounding);
	}

}

static bool
SceneToMeshData(const aiScene *scene, const load_config &config, mesh_data &md) {
	LoadMaterials(scene, md.materials);
	LoadMeshes(scene, config, md);
	
	return true;
}

//template<typename T>
//static void WriteElem(std::ostream &os, const T &elem) {
//	WriteSize(os, sizeof(T));
//	os.write((const char*)&elem, sizeof(T));
//}
//
//template<typename T>
//static void WriteElem(std::ostream &os, const T* elem, size_t sizeInBytes) {
//	WriteSize(os, uint32_t(sizeInBytes));
//	os.write((const char*)elem, sizeInBytes);
//}
//
//template<>
//static void WriteElem(std::ostream &os, const std::string &s) {
//	WriteSize(os, uint32_t(s.size()));
//	os.write(s.c_str(), s.size());
//}
//
//static void WriteElem(std::ostream &os, const char* v) {
//	WriteElem(os, v, strlen(v));
//}

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

static bool
WriteMeshData(const mesh_data &md, const std::string &srcfile, const std::string &outputfile) {
	std::ofstream off(outputfile, std::ios::binary);
	if (!off) {
		return false;		
	}

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

		WriteElemValue(off, "vb_layout", g.vb_layout);
		WriteElemValue(off, "num_vertices", g.num_vertices);		
		WriteElemValue(off, "vbraw", reinterpret_cast<const char *>(g.vbraw), CalcVertexSize(g.vb_layout) * g.num_vertices);		
		
		WriteElemValue(off, "ib_format", g.ib_format);
		WriteElemValue(off, "num_indices", g.num_indices);		
		WriteElemValue(off, "ibraw", reinterpret_cast<const char*>(g.ibraw), (g.ib_format == 16 ? 2 : 4) * g.num_indices);

		{
			WriteElemValue(off, "primitives");
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
		WriteSeparator(off);	// end group
	}
	WriteSeparator(off);	// end groups
	return true;
}

struct LayoutNamePairs {
	const char* name;
	bgfx::Attrib::Enum type;
};

//static LayoutNamePairs ATTRIB_NAME_PAIRS[bgfx::Attrib::Count] = {
//	{ "p", bgfx::Attrib::Position },
//	{ "n", bgfx::Attrib::Normal },
//	{ "T", bgfx::Attrib::Tangent},
//	{ "b", bgfx::Attrib::Bitangent},
//	{ "c0", bgfx::Attrib::Color0 },
//	{ "c1", bgfx::Attrib::Color1 },
//	{ "c2", bgfx::Attrib::Color2 },
//	{ "c3", bgfx::Attrib::Color3 },
//	{ "i", bgfx::Attrib::Indices},
//	{ "w", bgfx::Attrib::Weight},
//	{ "t0", bgfx::Attrib::TexCoord0},
//	{ "t1", bgfx::Attrib::TexCoord1},
//	{ "t2", bgfx::Attrib::TexCoord2},
//	{ "t3", bgfx::Attrib::TexCoord3},
//	{ "t4", bgfx::Attrib::TexCoord4},
//	{ "t5", bgfx::Attrib::TexCoord5},
//	{ "t6", bgfx::Attrib::TexCoord6},
//	{ "t7", bgfx::Attrib::TexCoord7},
//};

static std::vector<std::string> 
AdjustLayoutElem(const std::string &layout) {
	auto elems = Split(layout, '|');	
	for (auto &e : elems) {
		char newelem[] = "_30NIf";
		for (auto ii = 0; ii < e.size(); ++ii){
			newelem[ii] = e[ii];
		}
		e = newelem;
	}

	return elems;
}

static bgfx::VertexDecl 
gen_vertex_decl_from_vblayout(const std::string &vblayout) {
	auto elems = AdjustLayoutElem(vblayout);
	bgfx::VertexDecl decl;
	decl.begin();
	for (const auto &e : elems) {
		auto get_attrib = [](const std::string &e) {
			switch (e[0])
			{
			case 'p':return bgfx::Attrib::Position;
			case 'n':return bgfx::Attrib::Normal;
			case 'T':return bgfx::Attrib::Tangent;
			case 'b':return bgfx::Attrib::Bitangent;
			case 'i':return bgfx::Attrib::Indices;
			case 'w':return bgfx::Attrib::Weight;
			case 't': {
				auto channel = e[2] - '0';				
				return bgfx::Attrib::Enum(bgfx::Attrib::TexCoord0 + channel);
			}
			case 'c': {
				auto channel = e[2] - '0';
				return bgfx::Attrib::Enum(bgfx::Attrib::Color0 + channel);				
			}
			default:
				printf("not support type, %d", e[0]);
				return bgfx::Attrib::Count;
			}
		};

		auto attrib = get_attrib(e);

		uint8_t num = e[1] - '0';
		auto get_type = [](const std::string &e) {
			switch (e[5]){
			case 'f': return bgfx::AttribType::Float;
			case 'h': return bgfx::AttribType::Half;
			case 'u': return bgfx::AttribType::Uint8;
			case 'U': return bgfx::AttribType::Uint10;
			case 'i': return bgfx::AttribType::Int16;
			default:return bgfx::AttribType::Count;
			}
		};

		auto type = get_type(e);
		bool asInt = e[4] == 'i';
		bool normalize = e[3] == 'n';
		decl.add(attrib, num, type, normalize, asInt);
	}
	decl.end();
	return decl;
}

static std::string
gen_vblayout_from_decl(const bgfx::VertexDecl &decl) {
	std::string vblayout;
	for (uint32_t ii = bgfx::Attrib::Position; ii < bgfx::Attrib::Count; ++ii) {
		auto attrib = bgfx::Attrib::Enum(ii);
		if (decl.has(attrib)) {			
			uint8_t num;
			bgfx::AttribType::Enum type;
			bool normalize, asInt;
			decl.decode(attrib, num, type, normalize, asInt);

			auto get_attrib_name = [](bgfx::Attrib::Enum a, uint8_t num) {
				auto numstr = std::to_string(num);				
				const char* names[bgfx::Attrib::Count] = {
					"p0", "n0", "T0", "b0", 
					"c0", "c0", "c0", "c0",
					"i0", "w0", 
					"t0", "t1","t2","t3",
					"t4", "t5","t6","t7",
				};

				assert(bgfx::Attrib::Count > a);

				const char* name = names[a];
				return name[0] + std::to_string(num) + name[1];
			};

			if (!vblayout.empty())
				vblayout += '|';
			vblayout += get_attrib_name(attrib, num);
			vblayout += normalize ? 'n' : 'N';
			vblayout += asInt ? 'i' : 'I';

			auto get_type_char = [](bgfx::AttribType::Enum type) {
				char cc[bgfx::AttribType::Count] = {
					'u', 'U', 'i', 'h', 'f'
				};
				assert(bgfx::AttribType::Count > type);
				return cc[type];
			};

			vblayout += get_type_char(type);
		}
	}

	return vblayout;
};


static void 
LoadBGFXMesh(const std::string& filePath, mesh_data &md){
#define BGFX_CHUNK_MAGIC_VB  BX_MAKEFOURCC('V', 'B', ' ', 0x1)
#define BGFX_CHUNK_MAGIC_IB  BX_MAKEFOURCC('I', 'B', ' ', 0x0)
#define BGFX_CHUNK_MAGIC_IBC BX_MAKEFOURCC('I', 'B', 'C', 0x0)
#define BGFX_CHUNK_MAGIC_PRI BX_MAKEFOURCC('P', 'R', 'I', 0x0)

	bx::FileReader reader;		

	bx::open(&reader, filePath.c_str());

	uint32_t chunk;

	mesh_data::group group;
	while (4 == bx::read(&reader, chunk)){		
		switch (chunk){
		case BGFX_CHUNK_MAGIC_VB:{
			auto &bounding = group.bounding;
			bx::read(&reader, bounding.sphere);
			bx::read(&reader, bounding.aabb);
			glm::mat4x4 obb;
			bx::read(&reader, obb);

			bgfx::VertexDecl decl;
			bgfx::read(&reader, decl);
			group.vb_layout = gen_vblayout_from_decl(decl);

			uint16_t stride = decl.getStride();
			uint16_t numVertices;
			bx::read(&reader, numVertices);
			group.num_vertices = numVertices;
			const uint32_t vertexSizeInBytes = numVertices*stride;
			group.vbraw = new uint8_t[vertexSizeInBytes];
			bx::read(&reader, group.vbraw, vertexSizeInBytes);	
		}
		break;

		case BGFX_CHUNK_MAGIC_IB: {
			uint32_t numIndices;
			bx::read(&reader, numIndices);
			group.num_indices = numIndices;
			group.ib_format = 16;
			const uint32_t sizeInBytes = numIndices * 2;	// bgfx assume only use uint16_t type to save indices
			group.ibraw = new uint8_t[sizeInBytes];
			bx::read(&reader, group.ibraw, sizeInBytes);
		}
		break;
		case BGFX_CHUNK_MAGIC_IBC:{
			uint32_t numIndices;
			bx::read(&reader, numIndices);

			group.ibraw = new uint8_t[numIndices * 2];			

			uint32_t compressedSize;
			bx::read(&reader, compressedSize);

			std::vector<uint8_t> compressedIndices(compressedSize);
			bx::read(&reader, &compressedIndices[0], compressedSize);

			ReadBitstream rbs(compressedIndices.data(), compressedSize);
			DecompressIndexBuffer((uint16_t*)group.ibraw, numIndices / 3, rbs);
		}
		break;
		case BGFX_CHUNK_MAGIC_PRI: {
			auto read_name = [&md, &reader]() {
				uint16_t len;
				bx::read(&reader, len);

				std::string name;
				name.resize(len);
				bx::read(&reader, const_cast<char*>(name.c_str()), len);
				
				return name;				
			};

			group.name = read_name();

			uint16_t num;
			bx::read(&reader, num);

			group.primitives.resize(num);

			for (uint32_t ii = 0; ii < num; ++ii) {
				mesh_data::group::primitive_info &prim = group.primitives[ii];
				prim.name = read_name();
				
				uint32_t startIndex, numIndices;
				uint32_t startVertex, numVertices;

				bx::read(&reader, startIndex);
				prim.start_index = startIndex;
				bx::read(&reader, numIndices);
				prim.num_indices = numIndices;
				bx::read(&reader, startVertex);
				prim.start_vertex = startVertex;
				bx::read(&reader, numVertices);
				prim.num_vertices = numVertices;

				bx::read(&reader, prim.bounding.sphere);
				bx::read(&reader, prim.bounding.aabb);

				glm::mat4x4 obb;
				bx::read(&reader, obb);
			}

			md.groups.push_back(std::move(group));			
		}
		break;

		default:
			printf("%08x at %d", chunk, int32_t((bx::seek(&reader))));
			break;
		}
	}

	bx::close(&reader);
}

static void
convert_32bit_to_16bit(const uint32_t *src, uint16_t* dst, uint32_t num) {
	for (auto ii = 0UL; ii < num; ++ii) {
		dst[ii] = uint16_t(src[ii]);
	}
}

static void 
calc_tangents(mesh_data &md) {
	for (auto &g : md.groups) {
		auto newlayout = g.vb_layout;
		newlayout += "|T30nIf";
		newlayout += "|b30nIf";

		auto dstdecl = gen_vertex_decl_from_vblayout(newlayout);
		auto srcdecl = gen_vertex_decl_from_vblayout(g.vb_layout);

		auto stride = dstdecl.getStride();
		auto sizeInBytes = g.num_vertices * stride;
		uint8_t* buffer = new uint8_t[sizeInBytes + g.num_vertices * sizeof(float) * 6];	// tangent and bitangent have 6 float

		bgfx::vertexConvert(dstdecl, buffer, srcdecl, g.vbraw, uint32_t(g.num_vertices));

		if (g.ib_format == 32) {
			std::vector<uint16_t> u16buffer(g.num_indices);
			
			convert_32bit_to_16bit((const uint32_t*)g.ibraw, &u16buffer[0], uint32_t(g.num_indices));
			calcTangents(buffer, uint32_t(g.num_vertices), dstdecl, &u16buffer[0], uint32_t(g.num_indices));
		} else {
			calcTangents(buffer, uint32_t(g.num_vertices), dstdecl, (const uint16_t*)g.ibraw, uint32_t(g.num_indices));
		}

		

		delete[]g.vbraw;
		g.vb_layout = newlayout;
		g.vbraw = buffer;
	}
};

static void flip_uv(mesh_data &md) {
	for (auto &g : md.groups) {
		
		auto decl = gen_vertex_decl_from_vblayout(g.vb_layout);
		for (auto ii = 0; ii < 8; ++ii) {
			bgfx::Attrib::Enum a = bgfx::Attrib::Enum(bgfx::Attrib::TexCoord0 + ii);
			if (decl.has(a)) {
				for (auto iv = 0; iv < g.num_vertices; ++iv) {
					float output[4];
					bgfx::vertexUnpack(output, a, decl, g.vbraw, iv);

					output[1] = -output[1];
					
					uint8_t num;
					bgfx::AttribType::Enum type;
					bool normalize, asInt;					
					decl.decode(a, num, type, normalize, asInt);
					bgfx::vertexPack(output, normalize, a, decl, g.vbraw, iv);
				}

			}
		}
		
	}
	
}

static int convertBGFX(lua_State *L, const std::string &srcpath, const std::string &outputfile, const load_config &config) {
	mesh_data md;
	LoadBGFXMesh(srcpath, md);
	
	auto create_boundings = [](mesh_data &md) {
		auto &b = md.bounding;
		for (auto &g : md.groups) {
			auto &gb = g.bounding;
			for (auto &p : g.primitives) {
				gb.Merge(p.bounding);
			}
			b.Merge(gb);
		}
	};
	create_boundings(md);

	if (config.NeedCreateTangentSpaceData()){
		calc_tangents(md);
	}

	if (config.NeedFlipUV()) {
		flip_uv(md);
	}

	if (!WriteMeshData(md, srcpath, outputfile)) {
		luaL_error(L, "save to mesh file : %s failed!", outputfile.c_str());
	}

	return 0;
}

static bool 
convertFBX(lua_State *L, const std::string &srcpath, const std::string &outputfile, const load_config &config) {
	uint32_t import_flags = aiProcessPreset_TargetRealtime_MaxQuality;
	if (config.NeedCreateTangentSpaceData()) {
		import_flags |= aiProcess_CalcTangentSpace;
	}

	if (config.NeedFlipUV()) {
		import_flags |= aiProcess_FlipUVs;
	}

	Assimp::Importer importer;
	const aiScene* scene = importer.ReadFile(srcpath, import_flags);
	if (!scene) {
		luaL_error(L, "Error loading: %s", srcpath.c_str());
		return false;
	}

	aiNode* root_node = scene->mRootNode;
	if (!root_node) {
		luaL_error(L, "root not is invalid, source file : %s", srcpath);
		return false;
	}

	luaL_checkstack(L, 10, "");

	InitElemMap();

	mesh_data md;
	if (!SceneToMeshData(scene, config, md)) {
		luaL_error(L, "convert from assimp scene to mesh data failed, source file %s, dst file : %s", 
			srcpath.c_str(), outputfile.c_str());
		return false;
	}


	if (!WriteMeshData(md, srcpath, outputfile)) {
		luaL_error(L, "save to file : %s, failed!", outputfile.c_str());
		return false;
	}
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

int 
lconvertBGFXBin(lua_State *L) {
	return convertSource(L, convertBGFX);	
}

int
lconvertFBX(lua_State *L) {	
	return convertSource(L, convertFBX);
}

extern "C" {
	int32_t _main_(int32_t _argc, char** _argv) {
		return 0;
	}
}



