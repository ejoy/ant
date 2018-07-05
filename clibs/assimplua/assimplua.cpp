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

	unsigned vertex_count = 0;
	unsigned triangle_count = 0;
	
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

void PrintNodeHierarchy(aiNode* node, int space_count)
{
	aiString& node_name = node->mName;

	//打印名称
	printf_s("\n");
	for (int i = 0; i < space_count; ++i)
	{
		printf_s("\t");		//打印空格，方便看出顶点层级结构
	}
	printf_s("%s", node_name.C_Str());	//打印顶点名称

	int child_count = node->mNumChildren;
	if (child_count > 0)
	{
		for (int i = 0; i < child_count; ++i)
		{
			PrintNodeHierarchy(node->mChildren[i], space_count + 1);
		}
	}
}

/*
uint16_t vertex_count = 0;
uint32_t triangle_count = 0;

int start_vertex = 0;
int start_triangle = 0;
*/

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
			vertex.position.x = trans_vert.x;
			vertex.position.y = trans_vert.y;
			vertex.position.z = trans_vert.z;

			//printf("this vert %f, %f, %f\n", trans_vert.x, trans_vert.y, trans_vert.z);

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

		chunk.start_vertex += vertex_size;
		chunk.start_triangle += face_size;
		
		chunk.primitives.push_back(prim);
	}

	int child_count = node->mNumChildren;
	for(int i = 0; i < child_count; ++i)
	{
		//calculate child node
		aiNode* child_node = node->mChildren[i];
		ProcessNode(child_node, scene, parent_transform*node->mTransformation);
	}
}

//write node information into lua table
void WriteNodeToLua(lua_State *L, aiNode* node, const aiScene* scene)
{
	if (!node)
	{
		return;
	}

	lua_newtable(L);
	
	//set name
	const char* node_name = node->mName.C_Str();
	lua_pushstring(L, "name");
	lua_pushstring(L, node_name);
	lua_settable(L, -3);

	//set transform
	aiMatrix4x4 node_transform = node->mTransformation;
	lua_pushstring(L, "transform");

	lua_newtable(L);
	lua_pushnumber(L, 1);
	lua_pushnumber(L, node_transform.a1);
	lua_settable(L, -3);

	lua_pushnumber(L, 2);
	lua_pushnumber(L, node_transform.a2);
	lua_settable(L, -3);

	lua_pushnumber(L, 3);
	lua_pushnumber(L, node_transform.a3);
	lua_settable(L, -3);

	lua_pushnumber(L, 4);
	lua_pushnumber(L, node_transform.a4);
	lua_settable(L, -3);

	lua_pushnumber(L, 5);
	lua_pushnumber(L, node_transform.b1);
	lua_settable(L, -3);

	lua_pushnumber(L, 6);
	lua_pushnumber(L, node_transform.b2);
	lua_settable(L, -3);

	lua_pushnumber(L, 7);
	lua_pushnumber(L, node_transform.b3);
	lua_settable(L, -3);

	lua_pushnumber(L, 8);
	lua_pushnumber(L, node_transform.b4);
	lua_settable(L, -3);

	lua_pushnumber(L, 9);
	lua_pushnumber(L, node_transform.c1);
	lua_settable(L, -3);

	lua_pushnumber(L, 10);
	lua_pushnumber(L, node_transform.c2);
	lua_settable(L, -3);

	lua_pushnumber(L, 11);
	lua_pushnumber(L, node_transform.c3);
	lua_settable(L, -3);

	lua_pushnumber(L, 12);
	lua_pushnumber(L, node_transform.c4);
	lua_settable(L, -3);

	lua_pushnumber(L, 13);
	lua_pushnumber(L, node_transform.d1);
	lua_settable(L, -3);

	lua_pushnumber(L, 14);
	lua_pushnumber(L, node_transform.d2);
	lua_settable(L, -3);

	lua_pushnumber(L, 15);
	lua_pushnumber(L, node_transform.d3);
	lua_settable(L, -3);

	lua_pushnumber(L, 16);
	lua_pushnumber(L, node_transform.d4);
	lua_settable(L, -3);

	//set transofrm table
	lua_settable(L, -3);

	//set mesh
	lua_pushstring(L, "mesh");
	lua_newtable(L);

	for (unsigned i = 0; i < node->mNumMeshes; ++i)
	{
		//start from 1
		lua_pushnumber(L, i+1);
		lua_newtable(L);

		aiMesh* mesh = scene->mMeshes[node->mMeshes[i]];
		unsigned mat_idx = mesh->mMaterialIndex;
		aiMaterial* material = scene->mMaterials[mat_idx];
		printf("material index %d, %s\n", mat_idx, material->mProperties[1]->mKey.C_Str());

		//parse mesh data
		if (mesh->HasPositions())
		{
			lua_pushstring(L, "positions");
			lua_newtable(L);

			for (unsigned j = 0; j < mesh->mNumVertices; ++j)
			{
				lua_pushnumber(L, j * 3+1);
				lua_pushnumber(L, mesh->mVertices[j].x);
				lua_settable(L, -3);

				lua_pushnumber(L, j * 3+2);
				lua_pushnumber(L, mesh->mVertices[j].y);
				lua_settable(L, -3);

				lua_pushnumber(L, j * 3+3);
				lua_pushnumber(L, mesh->mVertices[j].z);
				lua_settable(L, -3);

			}

			lua_settable(L, -3);
		}

		if (mesh->HasNormals())
		{
			lua_pushstring(L, "normals");
			lua_newtable(L);

			for (unsigned j = 0; j < mesh->mNumVertices; ++j)
			{
				lua_pushnumber(L, j * 3+1);
				lua_pushnumber(L, mesh->mNormals[j].x);
				lua_settable(L, -3);

				lua_pushnumber(L, j * 3+2);
				lua_pushnumber(L, mesh->mNormals[j].y);
				lua_settable(L, -3);

				lua_pushnumber(L, j * 3+3);
				lua_pushnumber(L, mesh->mNormals[j].z);
				lua_settable(L, -3);
			}

			lua_settable(L, -3);
		}

		//for now, only texcoord0
		if (mesh->HasTextureCoords(0))
		{
			lua_pushstring(L, "texcoord0");
			lua_newtable(L);

			for (unsigned j = 0; j < mesh->mNumVertices; ++j)
			{
				lua_pushnumber(L, j * 3+1);
				lua_pushnumber(L, mesh->mTextureCoords[0][j].x);
				lua_settable(L, -3);

				lua_pushnumber(L, j * 3+2);
				lua_pushnumber(L, mesh->mTextureCoords[0][j].y);
				lua_settable(L, -3);

				lua_pushnumber(L, j * 3+3);
				lua_pushnumber(L, mesh->mTextureCoords[0][j].z);
				lua_settable(L, -3);
			}

			lua_settable(L, -3);		
		}

		if (mesh->HasFaces())
		{
			lua_pushstring(L, "indices");
			lua_newtable(L);

			int index_count = 1;
			for (unsigned j = 0; j < mesh->mNumFaces; ++j)
			{
				const aiFace& face = mesh->mFaces[j];

				for (unsigned k = 0; k < face.mNumIndices; ++k)
				{
					lua_pushnumber(L, index_count);
					lua_pushnumber(L, face.mIndices[k]);
					lua_settable(L, -3);
					++index_count;
				}					
			}

			lua_settable(L, -3);
		}

		lua_settable(L, -3);
	}

	lua_settable(L, -3);
	

	lua_pushstring(L, "children");
	lua_newtable(L);
	//set children
	for(unsigned i =0; i < node->mNumChildren; ++i)
	{
		lua_pushnumber(L, i + 1);
		WriteNodeToLua(L, node->mChildren[i], scene);
		lua_settable(L, -3);
		
	}
	lua_settable(L, -3);
}

//one material for one chunk
void ProcessMaterial(const aiScene* scene)
{
	unsigned mat_count = scene->mNumMaterials;
	for (unsigned i = 0; i < mat_count; ++i)
	{
		auto& chunk = g_ChunkArray[chunk_count];
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
		int vertex_size = sizeof(Vertex) * chunk.vertex_count;
		bx::write(&file_writer, &chunk.vertexArray[0], vertex_size);

		//这边就是index了
		bx::write(&file_writer, BGFX_CHUNK_MAGIC_IB);
		bx::write(&file_writer, chunk.triangle_count * 3);		//三角形数量
															//索引array
		bx::write(&file_writer, &chunk.triangleArray[0], sizeof(uint16_t)*chunk.triangle_count * 3);

		bx::write(&file_writer, BGFX_CHUNK_MAGIC_PRI); 
		uint16_t len = chunk.material.name.length;	//文件路径当作其名字
		bx::write(&file_writer, len);
		bx::write(&file_writer, chunk.material.name.C_Str());

		unsigned primitive_count = chunk.primitives.size();
		printf("prim coount: %d\n", primitive_count);

		bx::write(&file_writer, primitive_count);
		for (uint32_t ii = 0; ii < primitive_count; ++ii)
		{
			auto& prim = chunk.primitives[ii];
			uint16_t name_len = prim.name.size();
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
	
	bx::close(&file_writer);
	printf("\nWriting finished\n");

}

static int LoadFBXTest(lua_State *L)
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
		aiProcess_OptimizeMeshes;
		
	const aiScene* scene = importer.ReadFile(fbx_path, import_flags);
	if (!scene)
	{
		printf("Error loading: %s\n %s\n", fbx_path.data(), out_path.data());
		return 0;
	}

	ProcessMaterial(scene);

	aiNode* root_node = scene->mRootNode;

	if (!root_node)
	{
		return 0;
	}

	ProcessNode(root_node, scene, aiMatrix4x4());

	WriteChunkToBGFX(out_path);

	return 0;
}

static int AssimpImport(lua_State * L)
{
	/*
	Assimp::Importer importer;
	
	std::string in_path;	//输入路径
	std::string out_path;	//输出路径

	if (lua_isstring(L, 1))
	{
		in_path = lua_tostring(L, 1);
	}

	if (lua_isstring(L, 1))
	{
		out_path = lua_tostring(L, 2);
	}

//	printf("\n inpath: %s\n", in_path.data());
//	printf("outpath: %s\n", out_path.data());

	unsigned import_flags = 
		aiProcess_CalcTangentSpace		|
		aiProcess_Triangulate			|
		aiProcess_SortByPType			|
		aiProcess_OptimizeMeshes;

	const aiScene* scene = importer.ReadFile(in_path, import_flags);
	if (!scene)
	{
		printf("Error loading");
		return 0;
	}

	aiNode* root_node = scene->mRootNode;
	
	if(!root_node)
	{
		return 0;
	}

	//do a trick for unity here
	//todo: undo it later
	if(root_node->mNumChildren == 1)
	{
		root_node = root_node->mChildren[0];
		root_node = root_node->mChildren[0];
		root_node = root_node->mChildren[0];
	}
	
	ProcessNode(root_node, scene, aiMatrix4x4());

		
	//转换成bgfx的格式
	bgfx::VertexDecl decl;
	decl.begin();

	decl.add(bgfx::Attrib::Position, 3, bgfx::AttribType::Float);						//顶点位置
	decl.add(bgfx::Attrib::Normal, 3, bgfx::AttribType::Float, true, false);			//顶点法线
	decl.add(bgfx::Attrib::TexCoord0, 3, bgfx::AttribType::Float);
	decl.end();

	printf("\nStart Writing");

	bx::FileWriter file_writer;
	bx::Error b_error;

	//写文件
	bx::open(&file_writer, out_path.data(), false, &b_error);	//注意append(第三个参数选false,要不然不会覆盖前一个文件,而是写在后面)

																//现在按照bgfx标准的读取形式
	int stride = decl.getStride();
	//表示传入数据的类型
	//这个表示的是vertex buffer数据
	
	bx::write(&file_writer, BGFX_CHUNK_MAGIC_VB);

	Sphere max_sphere;
	calcMaxBoundingSphere(max_sphere, &g_VertexArray[0], vertex_count, stride);
	Sphere min_sphere;
	calcMinBoundingSphere(min_sphere, &g_VertexArray[0], vertex_count, stride);

	Sphere surround_sphere;
	//包围球
	min_sphere.m_radius < max_sphere.m_radius ? surround_sphere = max_sphere : surround_sphere = min_sphere;
	bx::write(&file_writer, surround_sphere);
	//aabb
	Aabb aabb;
	toAabb(aabb, &g_VertexArray[0], vertex_count, stride);
	bx::write(&file_writer, aabb);
	//obb
	Obb obb;
	calcObb(obb, &g_VertexArray[0], vertex_count, stride);
	bx::write(&file_writer, obb);
	//vertexdecl
	bgfx::write(&file_writer, decl);

	bx::write(&file_writer, vertex_count);		//顶点数量

												//然后是文件顶点array
	int vertex_size = sizeof(Vertex) * vertex_count;
	bx::write(&file_writer, &g_VertexArray[0], vertex_size);

	//这边就是index了
	bx::write(&file_writer, BGFX_CHUNK_MAGIC_IB);
	bx::write(&file_writer, triangle_count * 3);		//三角形数量
														//索引array
	bx::write(&file_writer, &g_TriangleArray[0], sizeof(uint16_t)*triangle_count * 3);

	bx::write(&file_writer, BGFX_CHUNK_MAGIC_PRI); //primitive,基本信息?
												   //暂时不管material
												   //只存储一个material,就是路径
	uint16_t len = out_path.size();	//文件路径当作其名字
	bx::write(&file_writer, len);
	bx::write(&file_writer, out_path.data());

	bx::write(&file_writer, primitive_count);
	for (uint32_t ii = 0; ii < primitive_count; ++ii)
	{
		auto& prim = g_PrimitiveArray[ii];
		uint16_t name_len = prim.name.size();
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

	bx::close(&file_writer);
	printf("\nWriting finished\n");

	*/
	return 0;
}

static const struct luaL_Reg myLib[] =
{
	{"assimp_import", LoadFBXTest},
	{"LoadFBXTest", LoadFBXTest},
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

