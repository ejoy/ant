#define LUA_LIB

#include <stdio.h>  
extern "C"
{
#include <lua.h>  
#include <lualib.h>
#include <lauxlib.h>
}
#include <vector>
#include <string>
#include <array>
//assimp include
#include <assimp\importer.hpp>
#include <assimp\postprocess.h>
#include <assimp\scene.h>

//bgfx include
#include <bx\string.h>
#include <bx\file.h>
#include <bgfx\bgfx.h>
#include <vertexdecl.h>

#include <common.h>
#include <bounds.h>

#include <assert.h>

#include <set>
#include <algorithm>
#include <unordered_map>
#include <functional>
#include <sstream>

//extern "C" int luaopen_assimplua(lua_State *L);

#define BGFX_CHUNK_MAGIC_VB  BX_MAKEFOURCC('V', 'B', ' ', 0x1)
#define BGFX_CHUNK_MAGIC_IB  BX_MAKEFOURCC('I', 'B', ' ', 0x0)
#define BGFX_CHUNK_MAGIC_IBC BX_MAKEFOURCC('I', 'B', 'C', 0x0)
#define BGFX_CHUNK_MAGIC_PRI BX_MAKEFOURCC('P', 'R', 'I', 0x0)

struct Vector3 {
	float x, y, z;
};

struct Vertex {
	Vector3 position;
	Vector3 normal;
	Vector3 texcoord0;
};

struct SMaterial 
{
	aiString name;
	aiColor3D diffuse;
	aiColor3D specular;

	//...
};

struct SPrimitive {
	SPrimitive() : m_startIndex(0), m_numIndices(0), m_startVertex(0), m_numVertices(0) {}

	std::string name;
	uint32_t m_startIndex;
	uint32_t m_numIndices;
	uint32_t m_startVertex;
	uint32_t m_numVertices;

	Sphere m_sphere;
	Aabb m_aabb;
	Obb m_obb;

	//srt
	aiVector3D m_scale;
	aiVector3D m_translation;
	aiVector3D m_rotation;
};

//最大的顶点数和索引数
const int MAX_VERTEX_SIZE = 64 * 1024;
const int MAX_TRIANGLE_SIZE = 128 * 1024;
struct SChunk
{
	SMaterial material;
	std::vector<SPrimitive> primitives;

	std::array<Vertex, MAX_VERTEX_SIZE> vertexArray;
	std::array<uint16_t, MAX_TRIANGLE_SIZE> triangleArray;

	uint16_t vertex_count = 0;
	uint16_t triangle_count = 0;
	
	int start_vertex = 0;
	int start_triangle = 0;
};
uint16_t chunk_count = 0;

struct SMesh {
	std::vector<aiVector3D> node_position;
	std::vector<aiVector3D> node_normal;
	std::vector<aiVector3D> node_texcoord0;
	std::vector<unsigned> node_idx;
};

struct SNode {
	std::string node_name;
	aiMatrix4x4 node_transform;
	std::vector<SMesh> node_mesh;
	std::vector<SNode*> children;
};

std::array<SChunk, 128>  g_ChunkArray;

std::vector<SMaterial> g_Material;

void ProcessNode(aiNode* node, const aiScene* scene, const aiMatrix4x4& parent_transform)
{
	int mesh_count = node->mNumMeshes;
	for(int i = 0; i < mesh_count; ++i)
	{
		//process mesh info
		aiMesh* a_mesh = scene->mMeshes[node->mMeshes[i]];
		//find chunk/material
		unsigned mat_idx = a_mesh->mMaterialIndex;
		auto& chunk = g_ChunkArray[mat_idx];

		int vertex_size = a_mesh->mNumVertices;
		int face_size = a_mesh->mNumFaces;

		SPrimitive prim;

		prim.name = std::string(a_mesh->mName.C_Str());
		prim.m_startIndex = chunk.start_triangle * 3;
		prim.m_startVertex = chunk.start_vertex;
		prim.m_numIndices = face_size * 3;
		prim.m_numVertices = vertex_size;

		chunk.vertex_count += vertex_size;
		chunk.triangle_count += face_size;

		//printf("mesh no.%d, vertex size: %d, face size: %d\n", i, vertex_size, face_size);


		for (int j = 0; j < vertex_size; ++j)
		{
			const aiVector3D& vert = a_mesh->mVertices[j];
			const aiVector3D& norm = a_mesh->mNormals[j];

			aiVector3D trans_vert = parent_transform * vert;
			aiVector3D trans_norm = parent_transform * norm;

			auto& vertex = chunk.vertexArray[chunk.start_vertex + j];
			vertex.position.x = -trans_vert.x;
			vertex.position.y = trans_vert.y;
			vertex.position.z = -trans_vert.z;

			//printf("this vert %f, %f, %f\n", vertex.position.x, vertex.position.y, vertex.position.z);

			vertex.normal.x = trans_norm.x;
			vertex.normal.y = trans_norm.y;
			vertex.normal.z = trans_norm.z;

			if (a_mesh->HasTextureCoords(0))
			{
				vertex.texcoord0.x = a_mesh->mTextureCoords[0][j].x;
				vertex.texcoord0.y = a_mesh->mTextureCoords[0][j].y;
				vertex.texcoord0.z = a_mesh->mTextureCoords[0][j].z;
			}
			else
			{
				vertex.texcoord0.x = 0;
				vertex.texcoord0.y = 0;
				vertex.texcoord0.z = 0;
			}
		}

		for (int j = 0; j < face_size; ++j)
		{
			const aiFace& face = a_mesh->mFaces[j];

		//	BX_CHECK(face.mNumIndices == 3, "Mesh must be triangulated");
			if (face.mNumIndices != 3)
			{
				continue;
			}

			chunk.triangleArray[chunk.start_triangle * 3 + j * 3] = face.mIndices[0] + chunk.start_vertex;
			chunk.triangleArray[chunk.start_triangle * 3 + j * 3 + 1] = face.mIndices[1] + chunk.start_vertex;
			chunk.triangleArray[chunk.start_triangle * 3 + j * 3 + 2] = face.mIndices[2] + chunk.start_vertex;

		}

		aiMatrix4x4 transformation = parent_transform * node->mTransformation;
		transformation.Decompose(prim.m_scale, prim.m_rotation, prim.m_translation) ;

		chunk.start_vertex += vertex_size;
		chunk.start_triangle += face_size;
		
		chunk.primitives.push_back(prim);
	}

	int child_count = node->mNumChildren;
	for(int i = 0; i < child_count; ++i)
	{
		aiNode* child_node = node->mChildren[i];
		//calculate child node
		std::string node_name = node->mName.C_Str();
		//if (node_name.find("Geometric") == std::string::npos)
		{
			ProcessNode(child_node, scene, parent_transform*node->mTransformation);
		}
		//else
		{
			//ignore geometric translation
		//	ProcessNode(child_node, scene, parent_transform);
		}
		
	}
}

//write node information into lua table
//void WriteNodeToLua(lua_State *L, aiNode* node, const aiScene* scene, const char* parent_name) {
//	if (!node) {
//		return;
//	}
//
//	luaL_checkstack(L, 10, "stack not big enough");
//	// node = {}
//	lua_newtable(L);
//
//	const char* node_name = node->mName.C_Str();
//	
//	// node.name = node_name
//	lua_pushstring(L, node_name);
//	lua_setfield(L, -2, "name");
//
//	// node.parent_name = parent_name
//	if (parent_name) {
//		lua_pushstring(L, parent_name);
//		lua_setfield(L, -2, "parent_name");
//	}
//
//	//set transform
//	aiMatrix4x4 node_transform = node->mTransformation;
//
//	// transform = {}
//	lua_newtable(L);
//
//	const ai_real *p = &node_transform.a1;
//	for (int ii = 0; ii < 16; ++ii) {		
//		lua_pushnumber(L, *p++);
//		lua_seti(L, -2, ii+1);	// ==> transofrm[ii+1] = *p++
//	}
//
//	// ==> node.transform = transform	
//	lua_setfield(L, -2, "transform");	
//
//	// mesh = {}
//	lua_newtable(L);
//
//	std::vector<Bounding>	boundings(node->mNumMeshes);
//
//	for (uint32_t i = 0; i < node->mNumMeshes; ++i) {
//		//start from 1
//		// group = {}
//		lua_newtable(L);
//
//		aiMesh* mesh = scene->mMeshes[node->mMeshes[i]];
//
//		// group.material_idx = mesh->mMaterialIndex+1
//		lua_pushnumber(L, mesh->mMaterialIndex+1);
//		lua_setfield(L, -2, "material_idx");	// 
//
//		// group.name = mesh->mName
//		lua_pushstring(L, mesh->mName.C_Str());
//		lua_setfield(L, -2, "name");
//
//		//parse mesh data
//		if (mesh->HasPositions()) {
//			AABB aabb;
//
//			// vertices = {}
//			lua_newtable(L);
//
//			/*
//			int stride = 12;
//
//			for (uint32_t j = 0; j < mesh->mNumVertices; ++j){
//
//				uint32_t stackidx = 1;
//				auto push_vector = [L, j, &stackidx](const ai_real *p, uint32_t num,int stride){
//					for (uint32_t iv = 0; iv < num; ++iv) {
//						lua_pushnumber(L, *p++);
//						lua_seti(L, -2, j * stride + (stackidx++));
//					}
//				};
//
//				push_vector(&(mesh->mVertices[j].x), 3,stride);
//				push_vector(&(mesh->mNormals[j].x), 3,stride);
//				push_vector(&(mesh->mTextureCoords[0][j].x), 3,stride);
//
//				push_vector(&(mesh->mTangents[j].x),3,stride);     // add tangent 
//
//				aabb.Append(mesh->mVertices[j]);
//			*/
//
//			auto calc_buf_size = [](aiMesh *mesh) {
//				size_t elemsize = 0;
//				if (mesh->HasPositions())
//					elemsize += sizeof(aiVector3D);
//				if (mesh->HasNormals())
//					elemsize += sizeof(aiVector3D);
//				if (mesh->HasTextureCoords(0))
//					elemsize += sizeof(aiVector3D);
//				if (mesh->HasTangentsAndBitangents())
//					elemsize += sizeof(aiVector3D);
//				return elemsize * mesh->mNumVertices;
//			};
//
//			const size_t bufsize = calc_buf_size(mesh);
//
//			// todo: actually, we can create struct of array, that say, we no need to copy data in new buffer. need support struct of array
//			// here is array of struct approach 
//			aiVector3D *buf = reinterpret_cast<aiVector3D*>(lua_newuserdata(L, bufsize));
//
//			for (uint32_t j = 0; j < mesh->mNumVertices; ++j) {
//				if (mesh->HasPositions()) {
//					*buf++ = mesh->mVertices[j];
//					aabb.Append(mesh->mVertices[j]);
//				}					
//				if (mesh->HasNormals())
//					*buf++ = mesh->mNormals[j];
//				if (mesh->HasTextureCoords(0))
//					*buf++ = mesh->mTextureCoords[0][j];
//				if( mesh->HasTangentsAndBitangents())
//				    *buf++ = mesh->mTangents[j];
//			}
//			lua_setfield(L, -2, "vertices");	// mesh.vertices = vertices
//
//			//{@	aabb & sphere
//			BoundingSphere sphere;
//			sphere.Init(aabb);
//
//			push_aabb(L, aabb, -2);
//			push_sphere(L, sphere, -2);
//
//			boundings[i].aabb = aabb;
//			boundings[i].sphere = sphere;
//			//@}
//		}
//
//		if (mesh->HasFaces()) {
//			size_t numelem = 0;
//			for (uint32_t ii = 0; ii < mesh->mNumFaces; ++ii) {
//				numelem += mesh->mFaces[ii].mNumIndices;
//			}
//
//			uint32_t *buf = reinterpret_cast<uint32_t *>(lua_newuserdata(L, numelem * sizeof(uint32_t)));
//
//			for (uint32_t ii = 0; ii < mesh->mNumFaces; ++ii) {
//				const auto &face = mesh->mFaces[ii];
//				memcpy(buf, face.mIndices, sizeof(uint32_t) * face.mNumIndices);
//			}
//			lua_setfield(L, -2, "indices");
//		}
//
//		lua_seti(L, -2, i + 1);	// mesh[i+1] = group
//	}
//
//	// node.mesh = mesh
//	lua_setfield(L, -2, "mesh");	
//	
//	AABB aabb;
//	for (const auto &b : boundings) {
//		aabb.Merge(b.aabb);
//	}
//
//	BoundingSphere sphere;
//	sphere.Init(aabb);
//
//	push_aabb(L, aabb, -2); // ==> aabb = {}; mesh.aabb = aabb
//	push_sphere(L, sphere, -2);	//==> sphere = {}; mesh.sphere = sphere
//	
//	// children = {}
//	lua_newtable(L);
//	
//	for(unsigned i =0; i < node->mNumChildren; ++i){ 
//		WriteNodeToLua(L, node->mChildren[i], scene, node_name);
//		lua_seti(L, -2, i + 1);
//	}
//
//	// node.children = children
//	lua_setfield(L, -2, "children");	// set to result table : children = {}; result.children = children
//}

//one material for one chunk
void ProcessMaterial(const aiScene* scene) {
	unsigned mat_count = scene->mNumMaterials;
	printf("mat counst %d\n", mat_count);
	for (unsigned i = 0; i < mat_count; ++i)
	{
		auto& chunk = g_ChunkArray[chunk_count];
		chunk.start_triangle = 0;
		chunk.start_vertex = 0;
		chunk.triangle_count = 0;
		chunk.vertex_count = 0;
		chunk.primitives.clear();

		SMaterial new_mat;
		aiMaterial* mat = scene->mMaterials[i];

		aiString name;
		if (AI_SUCCESS == mat->Get(AI_MATKEY_NAME, name))
		{
			new_mat.name = name;
		}

		aiColor3D diffuse;
		if (AI_SUCCESS == mat->Get(AI_MATKEY_COLOR_DIFFUSE, diffuse))
		{
			new_mat.diffuse = diffuse;
		}

		aiColor3D specular;
		if (AI_SUCCESS == mat->Get(AI_MATKEY_COLOR_SPECULAR, specular))
		{
			new_mat.specular = specular;
		}

		chunk.material = new_mat;

		++chunk_count;
	}
}

void WriteChunkToBGFX(const std::string& out_path) {

	//转换成bgfx的格式
	bgfx::VertexDecl decl;
	decl.begin();

	decl.add(bgfx::Attrib::Position, 3, bgfx::AttribType::Float);						//顶点位置
	decl.add(bgfx::Attrib::Normal, 3, bgfx::AttribType::Float, true, false);			//顶点法线
	decl.add(bgfx::Attrib::TexCoord0, 3, bgfx::AttribType::Float);
	decl.end();

	printf("\nStart Writing\n");

	bx::FileWriter file_writer;
	bx::Error b_error;

	//写文件
	bx::open(&file_writer, out_path.data(), false, &b_error);	//注意append(第三个参数选false,要不然不会覆盖前一个文件,而不是写在后面)

	//现在按照bgfx标准的读取形式
	int stride = decl.getStride();
	//表示传入数据的类型
	//这个表示的是vertex buffer数据

	printf("chunk count: %d\n", chunk_count);
	for (int chunk_idx = 0; chunk_idx < chunk_count; ++chunk_idx)
	{
		auto& chunk = g_ChunkArray[chunk_idx];
		bx::write(&file_writer, BGFX_CHUNK_MAGIC_VB);
	
		Sphere max_sphere;
		calcMaxBoundingSphere(max_sphere, &chunk.vertexArray[0], chunk.vertex_count, stride);
		Sphere min_sphere;
		calcMinBoundingSphere(min_sphere, &chunk.vertexArray[0], chunk.vertex_count, stride);

		Sphere surround_sphere;
		//包围球
		min_sphere.m_radius < max_sphere.m_radius ? surround_sphere = max_sphere : surround_sphere = min_sphere;
		bx::write(&file_writer, surround_sphere);
		//aabb
		Aabb aabb;
		toAabb(aabb, &chunk.vertexArray[0], chunk.vertex_count, stride);
		bx::write(&file_writer, aabb);
		//obb
		Obb obb;
		calcObb(obb, &chunk.vertexArray[0], chunk.vertex_count, stride);
		bx::write(&file_writer, obb);
		//vertexdecl
		bgfx::write(&file_writer, decl);

		bx::write(&file_writer, chunk.vertex_count);		//顶点数量

													//然后是文件顶点array
		uint32_t vertex_size = sizeof(Vertex) * chunk.vertex_count;
		bx::write(&file_writer, &chunk.vertexArray[0], vertex_size);

		//这边就是index了
		bx::write(&file_writer, BGFX_CHUNK_MAGIC_IB);
		bx::write(&file_writer, chunk.triangle_count * 3);		//三角形数量
															//索引array
		bx::write(&file_writer, &chunk.triangleArray[0], sizeof(uint16_t)*chunk.triangle_count * 3);

		bx::write(&file_writer, BGFX_CHUNK_MAGIC_PRI); 
		uint16_t len = static_cast<uint16_t>(chunk.material.name.length);	//文件路径当作其名字
		bx::write(&file_writer, len);
		bx::write(&file_writer, chunk.material.name.C_Str());
	
		//must be uint16_t!!
		uint16_t primitive_count = static_cast<uint16_t>(chunk.primitives.size());

		bx::write(&file_writer, primitive_count);
		for (uint16_t ii = 0; ii < primitive_count; ++ii)
		{
			auto& prim = chunk.primitives[ii];
			uint16_t name_len = static_cast<uint16_t>(prim.name.size());
			bx::write(&file_writer, name_len);
			bx::write(&file_writer, prim.name.data());

			bx::write(&file_writer, prim.m_startIndex);
			bx::write(&file_writer, prim.m_numIndices);
			bx::write(&file_writer, prim.m_startVertex);
			bx::write(&file_writer, prim.m_numVertices);
			
			bx::write(&file_writer, surround_sphere);	//暂时随便弄一个
			bx::write(&file_writer, aabb);
			bx::write(&file_writer, obb);
		}
	}

	printf("\nWriting finished\n");
	bx::close(&file_writer);

}

static int AssimpImport(lua_State *L)
{
	Assimp::Importer importer;

	std::string out_path;
	if (lua_isstring(L, -1))
	{
		out_path = lua_tostring(L, -1);
		lua_pop(L, 1);
	}
	else
	{
		return 0;
	}

	std::string fbx_path;
	if (lua_isstring(L, -1))
	{
		fbx_path = lua_tostring(L, -1);
		lua_pop(L, 1);
	}
	else
	{
		return 0;
	}

	unsigned import_flags =
		aiProcess_CalcTangentSpace |
		aiProcess_Triangulate |
		aiProcess_SortByPType |
		aiProcess_FlipWindingOrder |
		aiProcess_MakeLeftHanded;

	const aiScene* scene = importer.ReadFile(fbx_path, import_flags);
	
	if (!scene)
	{
		printf("Error loading: %s\n %s\n", fbx_path.data(), out_path.data());
		return 0;
	}

	chunk_count = 0;
	ProcessMaterial(scene);

	aiNode* root_node = scene->mRootNode;

	if (!root_node)
	{
		return 0;
	}

	//do a trick for unity here
	//todo: undo it later
	if (root_node->mNumChildren == 1)
	{
		std::string node_name;
		do
		{
			root_node = root_node->mChildren[0];
			node_name = root_node->mName.C_Str();
		} while (node_name.find("_$AssimpFbx$_") != std::string::npos && node_name.find("Geometric") == std::string::npos);
	}

	ProcessNode(root_node, scene, aiMatrix4x4());

	WriteChunkToBGFX(out_path);

	return 0;
}

int lconvertFBX(lua_State *L);
int lconvertBGFXBin(lua_State *L);
//int lconvertOZZMesh(lua_State *L);

static const struct luaL_Reg myLib[] = {
	{"assimp_import", AssimpImport},
	{"convert_FBX", lconvertFBX},
	{"convert_BGFXBin", lconvertBGFXBin},
	//{"convert_OZZ", lconvertOZZMesh},
	{ NULL, NULL }      
};

extern "C" {
	// not use LUAMOD_API here, when a dynamic lib linking in GCC compiler with static lib which limit symbol export, 
	// it will cause this dynamic lib not export all symbols by default
#if defined(_MSC_VER)
	//  Microsoft 
#define EXPORT __declspec(dllexport)
#define IMPORT __declspec(dllimport)
#elif defined(__GNUC__)
	//  GCC
//#define EXPORT	__attribute__(visibility("default"))
	// need force export, visibility("default") will follow static lib setting
#define EXPORT	__attribute__((dllexport))
#define IMPORT
#else
	//  do nothing and hope for the best?
#define EXPORT
#define IMPORT
#pragma warning Unknown dynamic link import/export semantics.
#endif
	EXPORT int
	luaopen_assimplua(lua_State *L)	{
		luaL_newlib(L, myLib);
		return 1;     
	}
}

