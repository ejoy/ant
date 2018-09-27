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

using MeshArray = std::vector<aiMesh*>;
using MeshMaterialArray = std::vector<MeshArray>;

static void
SeparateMeshByMaterialID(const aiScene *scene, MeshMaterialArray &mm) {
	mm.resize(scene->mNumMaterials);
	for (uint32_t ii = 0; ii < scene->mNumMaterials; ++ii) {
		auto mesh = scene->mMeshes[ii];
		MeshArray &meshes = mm[mesh->mMaterialIndex];
		meshes.push_back(mesh);
	}
}

// only valid in array of struct
static std::string
CreateVertexLayout(aiMesh *mesh, const std::string &vertexElemNeeded) {
	auto elems = AdjustLayoutElem(vertexElemNeeded);
	std::string layout;
	auto append_elem = [&layout](const std::string &e) {
		if (!layout.empty())
			layout += '|';
		layout += e;
	};
	for (const auto &e : elems) {
		switch (e[0]) {
		case 'p': if (mesh->HasPositions()) append_elem(e); break;
		case 'n': if (mesh->HasNormals()) append_elem(e); break;
		case 'b':
		case 'T': if (mesh->HasTangentsAndBitangents()) append_elem(e); break;
		case 'c': if (mesh->HasVertexColors(e[2] - '0')) append_elem(e); break;
		case 't': if (mesh->HasTextureCoords(e[2] - '0')) append_elem(e); break;
		case 'w':
		case 'i':
		default:
			printf("not support type : %d", e[0]);
			break;
		}
	}
	return layout;
}

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

static const void*
GetMeshDataPtr(const aiMesh *mesh, const std::string &elem, size_t offset) {
	const uint32_t count = elem[1] - '0';
	const uint32_t channel = elem[2] - '0';
	const float *p = nullptr;
	switch (elem[0]) {
	case 'p': p = &(mesh->mVertices[offset].x); break;
	case 'n': p = &(mesh->mNormals[offset].x); break;
	case 'T': p = &(mesh->mTangents[offset].x); break;
	case 'b': p = &(mesh->mBitangents[offset].x); break;
	case 'c': p = &(mesh->mColors[channel][offset].r); break;
	case 't': p = &(mesh->mTextureCoords[channel][offset].x); break;
	case 'i':
	case 'w':
	default:
		printf("not support type in CopyMeshVertices, %d", elem[0]);
		break;
	}

	return p;
}

static void
CopyMeshVerticesAsSOA(const aiMesh *mesh, size_t startVB, vb_info &vb) {
	auto elems = AdjustLayoutElem(vb.layout);

	for (size_t ii = 0; ii < elems.size(); ++ii) {
		const auto &e = elems[ii];
		auto &ptr = vb.vbraws[ii];

		auto p = GetMeshDataPtr(mesh, e, 0);

		auto elemSizeInBytes = GetVertexElemSizeInBytes(e);
		auto sizeInBytes = mesh->mNumVertices * elemSizeInBytes;

		uint8_t *dstp = ptr.get() + startVB * elemSizeInBytes;
		memcpy(dstp, p, sizeInBytes);
	}
}

static void
CopyMeshVerticesAsAOS(const aiMesh *mesh, size_t startVB, vb_info &vb) {
	const size_t vertexSizeInBytes = CalcVertexSize(vb.layout);
	uint8_t *vertices = vb.vbraws.back().get() + startVB * vertexSizeInBytes;

	auto elems = AdjustLayoutElem(vb.layout);
	for (uint32_t ii = 0; ii < mesh->mNumVertices; ++ii) {
		for (const auto& e : elems) {

			auto p = GetMeshDataPtr(mesh, e, ii);
			auto elemSizeInBytes = GetVertexElemSizeInBytes(e);
			memcpy(vertices, p, elemSizeInBytes);
			vertices += elemSizeInBytes;
		}
	}
}

static size_t
CopyMeshIndices(const aiMesh *mesh, const load_config &config, size_t startIB, ib_info &ib) {
	const bool is32bit = (config.flags & load_config::IndexBuffer32Bit);
	const size_t elemSize = is32bit ? 4 : 2;
	uint8_t *indices = ib.ibraw + startIB * elemSize;
	auto cp_op32 = [](const aiFace &face, uint8_t *&indices) {
		const size_t sizeInBytes = face.mNumIndices * sizeof(uint32_t);
		memcpy(indices, face.mIndices, sizeInBytes);
		indices += sizeInBytes;
	};
	auto cp_op16 = [](const aiFace &face, uint8_t *&indices) {
		const size_t sizeInBytes = face.mNumIndices * sizeof(uint16_t);
		uint16_t *uint16Indices = reinterpret_cast<uint16_t*>(indices);
		for (uint32_t ii = 0; ii < face.mNumIndices; ++ii) {
			*uint16Indices++ = static_cast<uint16_t>(face.mIndices[ii]);
		}

		indices += sizeInBytes;
	};

	auto cp_op = is32bit ? cp_op32 : cp_op16;

	size_t numIndices = 0;
	for (uint32_t ii = 0; ii < mesh->mNumFaces; ++ii) {
		const auto& face = mesh->mFaces[ii];
		cp_op(face, indices);
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

static void
InitVertexBuffer(vb_info &vb) {
	assert(vb.num_vertices != 0);
	assert(!vb.layout.empty());
	assert(vb.vbraws.empty());

	if (vb.soa) {
		const auto elems = AdjustLayoutElem(vb.layout);
		vb.vbraws.resize(elems.size());
		for (size_t ii = 0; ii < elems.size(); ++ii) {

			// only add one elem, for using bgfx::VertexDecl::getStride method to calculate one elem size in bytes
			const bgfx::VertexDecl decl = GenVertexDeclFromVBLayout(elems[ii]);
			const size_t elemSizeInBytes = decl.getStride();

			vb.vbraws[ii] = std::make_unique<uint8_t[]>(elemSizeInBytes * vb.num_vertices);
		}
	} else {
		vb.vbraws.push_back(std::make_unique<uint8_t[]>(CalcVertexSize(vb.layout) * vb.num_vertices));
	}
}

static void
LoadFBXMeshes(const aiScene *scene, const load_config& config, mesh_data &md) {
	MeshMaterialArray mm;
	SeparateMeshByMaterialID(scene, mm);

	md.groups.resize(mm.size());

	for (size_t ii = 0; ii < mm.size(); ++ii) {
		const auto &meshes = mm[ii];
		if (meshes.empty())
			continue;
		auto &group = md.groups[ii];
		auto &vb = group.vb;
		vb.layout = CreateVertexLayout(meshes.back(), config.layout);

		size_t vertexSizeInBytes = 0, indexSizeInBytes = 0, indexElemSizeInBytes = 0;
		CalcBufferSize(meshes, group.vb.layout, config, vertexSizeInBytes, indexSizeInBytes, indexElemSizeInBytes);

		vb.soa = config.NeedPackAsSOA();
		vb.num_vertices = vertexSizeInBytes / CalcVertexSize(vb.layout);

		InitVertexBuffer(vb);

		auto &ib = group.ib;

		ib.ibraw = new uint8_t[indexSizeInBytes];
		ib.num_indices = indexSizeInBytes / indexElemSizeInBytes;
		ib.format = indexElemSizeInBytes == 4 ? 32 : 16;

		group.primitives.resize(meshes.size());

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
			primitive.material_idx = mesh->mMaterialIndex + 1;

			// vertices
			if (vb.soa) {
				CopyMeshVerticesAsSOA(mesh, startVB, vb);
			} else {
				CopyMeshVerticesAsAOS(mesh, startVB, vb);
			}

			primitive.start_vertex = startVB;
			primitive.num_vertices = mesh->mNumVertices;

			startVB += mesh->mNumVertices;

			// indices
			size_t meshIndicesCount = CopyMeshIndices(mesh, config, startIB, ib);
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
	LoadFBXMeshes(scene, config, md);

	return true;
}

bool
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
