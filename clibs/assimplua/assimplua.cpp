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

void WriteMaterialToLua(lua_State *L, const aiScene* scene)
{
	unsigned mat_count = scene->mNumMaterials;
	for (unsigned i = 0; i < mat_count; ++i)
	{
		aiMaterial* mat = scene->mMaterials[i];
		
		lua_newtable(L);

		//{@	texture_path = {}
		{
			struct TexturePathInfo {
				const char* name;
				aiTextureType type;
				uint32_t idx;
			};

			TexturePathInfo typepaths[] = {
				{ "diffuse", aiTextureType_DIFFUSE, 0, },
				{ "ambient", aiTextureType_AMBIENT, 0, },
				{ "specular", aiTextureType_SPECULAR, 0, },
				{ "normals", aiTextureType_NORMALS, 0, },
				{ "shininess", aiTextureType_SHININESS, 0, },
				{ "lightmap", aiTextureType_LIGHTMAP, 0, },
			};

			lua_createtable(L, 0, sizeof(typepaths) / sizeof(typepaths[0]));

			for (const auto &info : typepaths) {
				aiString path;
				if (AI_SUCCESS == mat->Get(_AI_MATKEY_TEXTURE_BASE, info.type, info.idx, path)) {
					lua_pushstring(L, path.C_Str());
					lua_setfield(L, -2, info.name);
				}
			}

			lua_setfield(L, -2, "texture_path");
		}
		//@}


		aiString name;
		if (AI_SUCCESS == mat->Get(AI_MATKEY_NAME, name))
		{
			lua_pushstring(L, name.C_Str());
			lua_setfield(L, -2, "name");
		}

		//{@	material color
		{
			auto push_color = [L](const char* name, const aiColor3D &color) {
				lua_createtable(L, 0, 3);
				const char* elemnames[] = { "r", "g", "b" };
				for (uint32_t ii = 0; ii < 3; ++ii) {
					lua_pushnumber(L, color[ii]);
					lua_setfield(L, -2, elemnames[ii]);
				}

				lua_setfield(L, -2, name);
			};

			struct MatKeys { const char* k; int i, j; const char *name; };
			MatKeys keys[] = {
				{ AI_MATKEY_COLOR_AMBIENT, "ambient" },
			{ AI_MATKEY_COLOR_DIFFUSE, "diffuse" },
			{ AI_MATKEY_COLOR_SPECULAR, "specular" },
			};

			for (const auto &k : keys) {
				aiColor3D color;
				if (AI_SUCCESS == mat->Get(k.k, k.i, k.j, color)) {
					push_color(k.name, color);
				}
			}
		}
		//@}
		

		lua_seti(L, -2, i + 1);
	}
}

struct AABB {
	aiVector3D min;
	aiVector3D max;

	AABB() 
		: min(10e10f, 10e10f, 10e10f)
		, max(-10e10f, -10e10f, -10e10f)
	{

	}

	bool IsValid() const {		
		return min != aiVector3D(10e10f, 10e10f, 10e10f)
			&& max != aiVector3D(-10e10f, -10e10f, -10e10f);
	}

	void Init(const aiVector3D *vertiecs, uint32_t num) {
		min = aiVector3D(10e10f, 10e10f, 10e10f); 
		max = aiVector3D(-10e10f, -10e10f, -10e10f);

		for (uint32_t ii = 0; ii < num; ++ii) {
			const aiVector3D &v = vertiecs[ii];
			Append(v);
		}
	}

	void Append(const aiVector3D &v) {
		min.x = std::min(min.x, v.x);
		max.x = std::max(max.x, v.x);

		min.y = std::min(min.y, v.y);
		max.y = std::max(max.y, v.y);

		min.z = std::min(min.z, v.z);
		max.z = std::max(max.z, v.z);
	}

	void Transform(const aiMatrix4x4 &trans) {
		aiVector3D tmin = trans * min;
		aiVector3D tmax = trans * max;

		min.x = std::min(tmin.x, tmax.x);
		min.y = std::min(tmin.y, tmax.y);
		min.z = std::min(tmin.z, tmax.z);

		max.x = std::max(tmin.x, tmax.x);
		max.y = std::max(tmin.y, tmax.y);
		max.z = std::max(tmin.z, tmax.z);
	}


	void Merge(const AABB &other) {
		min.x = std::min(min.x, other.min.x);
		min.y = std::min(min.y, other.min.y);
		min.z = std::min(min.z, other.min.z);

		max.x = std::max(max.x, other.max.x);
		max.y = std::max(max.y, other.max.y);
		max.z = std::max(max.z, other.max.z);
	}
};

struct BoundingSphere {
	aiVector3D center;
	ai_real radius;

	void Init(const AABB &bb) {
		aiVector3D delta = bb.max - bb.min;
		center = bb.min + delta * 0.5f;
		radius = delta.Length();
	}
};

struct Bounding {
	AABB aabb;
	BoundingSphere sphere;
};

static void push_aabb(lua_State *L, const AABB &aabb, int32_t tblidx) {
	lua_createtable(L, 6, 0);
	const ai_real *p = &aabb.min.x;
	for (uint32_t ii = 0; ii < 6; ++ii) {
		lua_pushnumber(L, *p++);
		lua_seti(L, -2, ii + 1);
	}
	lua_setfield(L, tblidx, "aabb");
}

static void push_sphere(lua_State *L, const BoundingSphere &sphere, int32_t tblidx) {
	lua_createtable(L, 4, 0);
	const ai_real *p1 = &sphere.center.x;
	for (uint32_t ii = 0; ii < 4; ++ii) {
		lua_pushnumber(L, *p1++);
		lua_seti(L, -2, ii + 1);
	}

	lua_setfield(L, tblidx, "sphere");
}

static void push_sphere(lua_State *L, const AABB &aabb, int32_t tblidx) {
	BoundingSphere sphere; sphere.Init(aabb);
	push_sphere(L, sphere, tblidx);
}

//write node information into lua table
void WriteNodeToLua(lua_State *L, aiNode* node, const aiScene* scene, const char* parent_name) {
	if (!node) {
		return;
	}

	luaL_checkstack(L, 10, "stack not big enough");
	// node = {}
	lua_newtable(L);

	const char* node_name = node->mName.C_Str();
	
	// node.name = node_name
	lua_pushstring(L, node_name);
	lua_setfield(L, -2, "name");

	// node.parent_name = parent_name
	if (parent_name) {
		lua_pushstring(L, parent_name);
		lua_setfield(L, -2, "parent_name");
	}

	//set transform
	aiMatrix4x4 node_transform = node->mTransformation;

	// transform = {}
	lua_newtable(L);

	const ai_real *p = &node_transform.a1;
	for (int ii = 0; ii < 16; ++ii) {		
		lua_pushnumber(L, *p++);
		lua_seti(L, -2, ii+1);	// ==> transofrm[ii+1] = *p++
	}

	// ==> node.transform = transform	
	lua_setfield(L, -2, "transform");	

	// mesh = {}
	lua_newtable(L);

	std::vector<Bounding>	boundings(node->mNumMeshes);

	for (uint32_t i = 0; i < node->mNumMeshes; ++i) {
		//start from 1
		// group = {}
		lua_newtable(L);

		aiMesh* mesh = scene->mMeshes[node->mMeshes[i]];

		// group.material_idx = mesh->mMaterialIndex+1
		lua_pushnumber(L, mesh->mMaterialIndex+1);
		lua_setfield(L, -2, "material_idx");	// 

		// group.name = mesh->mName
		lua_pushstring(L, mesh->mName.C_Str());
		lua_setfield(L, -2, "name");

		//parse mesh data
		if (mesh->HasPositions()) {
			AABB aabb;

			// vertices = {}
			lua_newtable(L);

			/*
			int stride = 12;

			for (uint32_t j = 0; j < mesh->mNumVertices; ++j){

				uint32_t stackidx = 1;
				auto push_vector = [L, j, &stackidx](const ai_real *p, uint32_t num,int stride){
					for (uint32_t iv = 0; iv < num; ++iv) {
						lua_pushnumber(L, *p++);
						lua_seti(L, -2, j * stride + (stackidx++));
					}
				};

				push_vector(&(mesh->mVertices[j].x), 3,stride);
				push_vector(&(mesh->mNormals[j].x), 3,stride);
				push_vector(&(mesh->mTextureCoords[0][j].x), 3,stride);

				push_vector(&(mesh->mTangents[j].x),3,stride);     // add tangent 

				aabb.Append(mesh->mVertices[j]);
			*/

			auto calc_buf_size = [](aiMesh *mesh) {
				size_t elemsize = 0;
				if (mesh->HasPositions())
					elemsize += sizeof(aiVector3D);
				if (mesh->HasNormals())
					elemsize += sizeof(aiVector3D);
				if (mesh->HasTextureCoords(0))
					elemsize += sizeof(aiVector3D);
				if (mesh->HasTangentsAndBitangents())
					elemsize += sizeof(aiVector3D);
				return elemsize * mesh->mNumVertices;
			};

			const size_t bufsize = calc_buf_size(mesh);

			// todo: actually, we can create struct of array, that say, we no need to copy data in new buffer. need support struct of array
			// here is array of struct approach 
			aiVector3D *buf = reinterpret_cast<aiVector3D*>(lua_newuserdata(L, bufsize));

			for (uint32_t j = 0; j < mesh->mNumVertices; ++j) {
				if (mesh->HasPositions()) {
					*buf++ = mesh->mVertices[j];
					aabb.Append(mesh->mVertices[j]);
				}					
				if (mesh->HasNormals())
					*buf++ = mesh->mNormals[j];
				if (mesh->HasTextureCoords(0))
					*buf++ = mesh->mTextureCoords[0][j];
				if( mesh->HasTangentsAndBitangents())
				    *buf++ = mesh->mTangents[j];
			}
			lua_setfield(L, -2, "vertices");	// mesh.vertices = vertices

			//{@	aabb & sphere
			BoundingSphere sphere;
			sphere.Init(aabb);

			push_aabb(L, aabb, -2);
			push_sphere(L, sphere, -2);

			boundings[i].aabb = aabb;
			boundings[i].sphere = sphere;
			//@}
		}

		if (mesh->HasFaces()) {
			size_t numelem = 0;
			for (uint32_t ii = 0; ii < mesh->mNumFaces; ++ii) {
				numelem += mesh->mFaces[ii].mNumIndices;
			}

			uint32_t *buf = reinterpret_cast<uint32_t *>(lua_newuserdata(L, numelem * sizeof(uint32_t)));

			for (uint32_t ii = 0; ii < mesh->mNumFaces; ++ii) {
				const auto &face = mesh->mFaces[ii];
				memcpy(buf, face.mIndices, sizeof(uint32_t) * face.mNumIndices);
			}
			lua_setfield(L, -2, "indices");
		}

		lua_seti(L, -2, i + 1);	// mesh[i+1] = group
	}

	// node.mesh = mesh
	lua_setfield(L, -2, "mesh");	
	
	AABB aabb;
	for (const auto &b : boundings) {
		aabb.Merge(b.aabb);
	}

	BoundingSphere sphere;
	sphere.Init(aabb);

	push_aabb(L, aabb, -2); // ==> aabb = {}; mesh.aabb = aabb
	push_sphere(L, sphere, -2);	//==> sphere = {}; mesh.sphere = sphere
	
	// children = {}
	lua_newtable(L);
	
	for(unsigned i =0; i < node->mNumChildren; ++i){ 
		WriteNodeToLua(L, node->mChildren[i], scene, node_name);
		lua_seti(L, -2, i + 1);
	}

	// node.children = children
	lua_setfield(L, -2, "children");	// set to result table : children = {}; result.children = children
}

//one material for one chunk
void ProcessMaterial(const aiScene* scene)
{
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

void WriteChunkToBGFX(const std::string& out_path)
{

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

using MeshArray = std::vector<aiMesh*>;
using MeshMaterialArray = std::vector<MeshArray>;


struct LoadFBXConfig {
	LoadFBXConfig()
		: layout("p|n|T|b|t0|t1|t2|t3|t4|c0|c1|c2|c3")
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
		CreateNormal		= 0x00000001,
		CreateTangent		= 0x00000002,
		CreateBitangent		= 0x00000004,

		InvertNormal		= 0x00000010,
		FlipUV				= 0x00000020,
		IndexBuffer32Bit	= 0x00000040,

	};
	uint32_t flags;
};

static void SeparateMeshByMaterialID(const aiScene *scene, MeshMaterialArray &mm) {
	mm.resize(scene->mNumMaterials);
	for (uint32_t ii = 0; ii < scene->mNumMaterials; ++ii) {
		auto mesh = scene->mMeshes[ii];
		MeshArray &meshes = mm[mesh->mMaterialIndex];
		meshes.push_back(mesh);
	}
}

static inline std::vector<std::string> Split(const std::string &ss, char delim) {
	std::istringstream iss(ss);
	std::vector<std::string> vv;
	std::string elem;
	while (std::getline(iss, elem, '|')) {
		vv.push_back(elem);
	}

	return vv;
}

// only valid in array of struct
static std::string CreateVertexLayout(aiMesh *mesh, const std::string &vertexElemNeeded) {
	auto elems = Split(vertexElemNeeded, '|');

	auto has_elem = [&elems](const std::string &e) {
		return std::find(std::begin(elems), std::end(elems), e);
	};

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
			if (name.length() < 2){
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

	add_array_elem("t", 3, [mesh](uint32_t idx) {return mesh->HasTextureCoords(idx);});
	add_array_elem("c", 4, [mesh](uint32_t idx) {return mesh->HasVertexColors(idx); });

	return ss;
}

using VertexElemMap = std::unordered_map<std::string, std::function<float *(const aiMesh *mesh, uint32_t idx)> >;

VertexElemMap g_elemMap;
static void InitElemMap() {
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

static inline void extract_layout_elem_info(const std::string &le, std::string &type, uint8_t &count) {
	type = le.substr(0, 1) + le.substr(2, 1);
	count = static_cast<uint8_t>(std::stoi(le.substr(1, 1)));
}

static size_t CalcVertexSize(const std::string &layout, const LoadFBXConfig &config) {
	size_t elemSizeInBytes = 0;
	auto vv = Split(layout, '|');
	
	for (auto v : vv) {
		const std::string type = v.substr(0, 1);		
		const uint8_t elemCount = static_cast<uint8_t>(std::stoi(v.substr(1, 1)));
	
		elemSizeInBytes += elemCount * sizeof(float);
	}

	return elemSizeInBytes;
};

static void CalcBufferSize(	const MeshArray &meshes, 
							const std::string &layout, 
							const LoadFBXConfig &config, 
							size_t &vertexSizeInBytes, size_t &indexSizeInBytes, size_t &indexElemSizeInBytes){
	if (meshes.empty())
		return;
	
	const size_t elemSizeInBytes = CalcVertexSize(layout, config);

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
		indexElemSizeInBytes = ((config.flags & LoadFBXConfig::IndexBuffer32Bit) ? sizeof(uint32_t) : sizeof(uint16_t));
	}

	indexSizeInBytes = numIndices * indexElemSizeInBytes;
}

static void CopyMeshVertices(const aiMesh *mesh, const std::string &layout, const LoadFBXConfig &config, float * &vertices) {
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

static size_t CopyMeshIndices(const aiMesh *mesh, const LoadFBXConfig &config, uint8_t* &indices) {
	size_t numIndices = 0;
	for (uint32_t ii = 0; ii < mesh->mNumFaces; ++ii) {
		const auto& face = mesh->mFaces[ii];
		if (config.flags & LoadFBXConfig::IndexBuffer32Bit) {
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

static bool FindTransform(const aiScene *scene, const aiNode *node, const aiMesh *mesh, aiMatrix4x4 &mat) {
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

static std::pair<std::string, bgfx::AttribType::Enum> attrib_type_name_pairs[bgfx::AttribType::Count] = {
	{ "UINT8", bgfx::AttribType::Uint8 },
	{ "UINT10", bgfx::AttribType::Uint10 },
	{ "INT16", bgfx::AttribType::Int16 },
	{ "HALF", bgfx::AttribType::Half },
	{ "FLOAT", bgfx::AttribType::Float },
};

static inline bgfx::AttribType::Enum what_elem_type(const std::string &n) {
	for (auto &pp : attrib_type_name_pairs) {
		if (pp.first == n)
			return pp.second;
	}

	return bgfx::AttribType::Count;
}

#if defined(DISABLE_ASSERTS)
# define verify(expr) ((void)(expr))
#else
# define verify(expr) assert(expr)
#endif	

static void ExtractLoadConfig(lua_State *L, int idx, LoadFBXConfig &config) {
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

	extract_boolean("gen_normal", LoadFBXConfig::CreateNormal);	
	extract_boolean("tangentspace", LoadFBXConfig::CreateTangent);
	extract_boolean("tangentspace", LoadFBXConfig::CreateBitangent);

	extract_boolean("invert_normal", LoadFBXConfig::InvertNormal);
	extract_boolean("flip_uv", LoadFBXConfig::FlipUV);
	extract_boolean("ib_32", LoadFBXConfig::IndexBuffer32Bit);	
}


static int LoadFBX(lua_State *L)
{
	Assimp::Importer importer;
	
	std::string fbx_path;
	if (!lua_isstring(L, 1))
		return 0;
	
	fbx_path = lua_tostring(L, 1);	

	LoadFBXConfig config;
	ExtractLoadConfig(L, 2, config);

	uint32_t import_flags = aiProcessPreset_TargetRealtime_MaxQuality;
	if (config.NeedCreateTangentSpaceData()) {
		import_flags |= aiProcess_CalcTangentSpace;
	}

	if (config.NeedFlipUV()) {
		import_flags |= aiProcess_FlipUVs;
	}		

	const aiScene* scene = importer.ReadFile(fbx_path, import_flags);

	if (!scene)
	{
		printf("Error loading: %s\n", fbx_path.data());
		return 0;
	}

	aiNode* root_node = scene->mRootNode;

	if (!root_node)
	{
		printf("Root node Invalid\n");
		return 0;
	}

	InitElemMap();
	luaL_checkstack(L, 10, "");

	// node = {}
	lua_createtable(L, 0, 2);

	// materials = {}
	lua_newtable(L);
	WriteMaterialToLua(L, scene);

	// node.materials = materials
	lua_setfield(L, -2, "materials");


	AABB aabbGroup;
	// group = {}
	lua_newtable(L);	
	{
		MeshMaterialArray mm;
		SeparateMeshByMaterialID(scene, mm);
		
		for (size_t ii = 0; ii < mm.size(); ++ii) {
			AABB aabbMesh;
			// group[ii+1] = {}
			lua_newtable(L);

			const auto &meshes = mm[ii];

			if (meshes.empty())
				continue;

			const std::string vlayout = CreateVertexLayout(meshes.back(), config.layout);

			size_t vertexSizeInBytes = 0, indexSizeInBytes = 0, indexElemSizeInBytes = 0;
			CalcBufferSize(meshes, vlayout, config, vertexSizeInBytes, indexSizeInBytes, indexElemSizeInBytes);

			float *vertices = (float*)(lua_newuserdata(L, vertexSizeInBytes));
			lua_setfield(L, -2, "vb_raw");

			lua_pushnumber(L, (lua_Number)vertexSizeInBytes);
			lua_setfield(L, -2, "numVertices");

			lua_pushstring(L, vlayout.c_str());
			lua_setfield(L, -2, "vbLayout");

			uint8_t *indices = reinterpret_cast<uint8_t*>(lua_newuserdata(L, indexSizeInBytes));
			lua_setfield(L, -2, "ib_raw");

			lua_pushnumber(L, (lua_Number)indexSizeInBytes);
			lua_setfield(L, -2, "numIndices");

			lua_pushnumber(L, (lua_Number)(indexElemSizeInBytes == 4 ? 32 : 16));
			lua_setfield(L, -2, "ibFormat");

			// prim = {}
			lua_createtable(L, (int)meshes.size(), 0);

			size_t startVB = 0, startIB = 0;
			for (size_t jj = 0; jj < meshes.size(); ++jj) {
				// prim[jj+1] = {}
				lua_newtable(L);
				
				aiMesh *mesh = meshes[jj];

				aiMatrix4x4 transform;
				FindTransform(scene, scene->mRootNode, mesh, transform);
				{
					const ai_real *p = &transform.a1;
					lua_createtable(L, 16, 0);
					for (uint32_t ii = 0; ii < 16; ++ii) {
						lua_pushnumber(L, *p++);
						lua_seti(L, -2, ii + 1);
					}

					lua_setfield(L, -2, "transform");
				}

				lua_pushstring(L, mesh->mName.C_Str());
				lua_setfield(L, -2, "name");

				lua_pushnumber(L, mesh->mMaterialIndex + 1);
				lua_setfield(L, -2, "materialIdx");

				// vertices
				CopyMeshVertices(mesh, vlayout, config, vertices);

				lua_pushnumber(L, (lua_Number)startVB);
				lua_setfield(L, -2, "startVertex");

				lua_pushnumber(L, (lua_Number)mesh->mNumVertices);
				lua_setfield(L, -2, "numVertices");				

				startVB += mesh->mNumVertices;

				// indices
				size_t meshIndicesCount = CopyMeshIndices(mesh, config, indices);
				lua_pushnumber(L, (lua_Number)startIB);
				lua_setfield(L, -2, "startIndex");

				lua_pushnumber(L, (lua_Number)meshIndicesCount);
				lua_setfield(L, -2, "numIndices");


				//aabb
				AABB aabbPrim;
				aabbPrim.Init(mesh->mVertices, mesh->mNumVertices);
				push_aabb(L, aabbPrim, -2);
				push_sphere(L, aabbPrim, -2);


				lua_seti(L, -2, jj + 1);

				aabbMesh.Merge(aabbPrim);
			}

			lua_setfield(L, -2, "prim");

			push_aabb(L, aabbMesh, -2);
			push_sphere(L, aabbMesh, -2);

			// group[ii+1] = {}
			lua_seti(L, -2, ii + 1);

			aabbGroup.Merge(aabbMesh);
		}
	}
	
	// node.group = group
	lua_setfield(L, -2, "group");

	// node.aabb 
	push_aabb(L, aabbGroup, -2);
	// node.sphere
	push_sphere(L, aabbGroup, -2);

	//int num = lua_gettop(L);
	//for (auto ii = 0; ii < num; ++ii) {
	//	int type = lua_type(L, -(ii + 1));
	//	printf("%d\n", type);
	//}

	//WriteMaterialToLua(L, scene);
	//WriteNodeToLua(L, root_node, scene);
	
	//unsigned tex_count = scene->mNumTextures;
	//for (unsigned i = 0; i < tex_count; ++i)
	//{
	//	aiTexture* texture = scene->mTextures[i];
	//	printf("get textreureu %s\n", texture->mFilename.C_Str());
	//}

	printf("load finished\n");
	return 1;
}

static const struct luaL_Reg myLib[] =
{
	{"assimp_import", AssimpImport},
	{"LoadFBX", LoadFBX},
	{ NULL, NULL }      
};

extern "C"
{
	LUAMOD_API int 
	luaopen_assimplua(lua_State *L)
	{
		luaL_newlib(L, myLib);
		return 1;     
	}
}

