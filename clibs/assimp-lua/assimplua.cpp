#define LUA_LIB

#include <stdio.h>  
extern "C"
{
#include <lua.h>  
#include <lualib.h>
#include <lauxlib.h>
}

#include <string>
#include <array>
//assimp include
#include <assimp\Importer.hpp>
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

struct Primitive {
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
const int MAX_VERTEX_SIZE = 16 * 1024 * 1024;
const int MAX_TRIANGLE_SIZE = 16 * 1024 * 1024;

std::array<Vertex, MAX_VERTEX_SIZE> g_VertexArray;
std::array<uint16_t, MAX_TRIANGLE_SIZE> g_TriangleArray;
std::array<Primitive, 1024> g_PrimitiveArray;
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

static int AssimpImport(lua_State * L)
{
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

	const aiScene* scene = importer.ReadFile(in_path, 
		aiProcess_CalcTangentSpace		| 
		aiProcess_Triangulate			|
		aiProcess_JoinIdenticalVertices |
		aiProcess_SortByPType
		);
		
	
	if (!scene)
	{
		printf("Error loading");
		return 0;
	}

	aiNode* root_node = scene->mRootNode;
	if (root_node)
	{
		PrintNodeHierarchy(root_node, 0);
	}

	uint16_t vertex_count = 0;
	uint32_t triangle_count = 0;
	uint16_t primitive_count = 0;

	int start_vertex = 0;
	int start_triangle = 0;

	if (scene->HasMeshes())
	{
		int mesh_count = scene->mNumMeshes;
		printf("\n");

		for (int i = 0; i < mesh_count; ++i)
		{
			aiMesh* a_mesh = scene->mMeshes[i];

			int vertex_size = a_mesh->mNumVertices;
			int face_size = a_mesh->mNumFaces;

			auto& prim = g_PrimitiveArray[primitive_count];

			prim.name = std::string(a_mesh->mName.C_Str());
			prim.m_startIndex = start_triangle * 3;
			prim.m_startVertex = start_vertex;
			prim.m_numIndices = face_size * 3;
			prim.m_numVertices = vertex_size;

			vertex_count += vertex_size;
			triangle_count += face_size;

			printf("mesh no.%d, vertex size: %d, face size: %d\n", i, vertex_size, face_size);


			for (int j = 0; j < vertex_size; ++j)
			{
				const aiVector3D& vert = a_mesh->mVertices[j];
				const aiVector3D& norm = a_mesh->mNormals[j];

				auto& vertex = g_VertexArray[start_vertex + j];
				vertex.position.x = vert.x;
				vertex.position.y = vert.y;
				vertex.position.z = vert.z;

				vertex.normal.x = norm.x;
				vertex.normal.y = norm.y;
				vertex.normal.z = norm.z;

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

				g_TriangleArray[start_triangle * 3 + j * 3] = face.mIndices[0] + start_vertex;
				g_TriangleArray[start_triangle * 3 + j * 3 + 1] = face.mIndices[1] + start_vertex;
				g_TriangleArray[start_triangle * 3 + j * 3 + 2] = face.mIndices[2] + start_vertex;

			}


			start_vertex += vertex_size;
			start_triangle += face_size;
			++primitive_count;
		}

	}

	//暂时先只导出顶点位置和面信息
	printf("vertex count: %d, triangle count: %d", vertex_count, triangle_count);
	
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

	
	return 0;
}

static const struct luaL_Reg myLib[] =
{
	{"assimp_import", AssimpImport},
	{ NULL, NULL }      
};

extern "C"
LUAMOD_API int 
luaopen_assimplua(lua_State *L)
{
	luaL_newlib(L, myLib);
	return 1;     
}
