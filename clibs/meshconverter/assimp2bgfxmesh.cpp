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
	for (int i = 0; i < mesh_count; ++i)
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
			} else
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
		transformation.Decompose(prim.m_scale, prim.m_rotation, prim.m_translation);

		chunk.start_vertex += vertex_size;
		chunk.start_triangle += face_size;

		chunk.primitives.push_back(prim);
	}

	int child_count = node->mNumChildren;
	for (int i = 0; i < child_count; ++i)
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
	} else
	{
		return 0;
	}

	std::string fbx_path;
	if (lua_isstring(L, -1))
	{
		fbx_path = lua_tostring(L, -1);
		lua_pop(L, 1);
	} else
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