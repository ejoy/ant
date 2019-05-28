#include "meshdata.h"
#include "utils.h"
extern "C" {
#include <lua.h>  
#include <lualib.h>
#include <lauxlib.h>
}

//#define __USE_LOCAL_INDEX 1

//assimp include
#include <assimp/Importer.hpp>
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
static LayoutArray
CreateVertexLayout(aiMesh *mesh, const LayoutArray &layouts) {
	LayoutArray new_layouts = layouts;

	for (auto &layout : new_layouts) {
		auto elems = AdjustLayoutElem(layout);
		std::string new_layout;
		auto append_elem = [&new_layout](const std::string &e) {
			if (!new_layout.empty())
				new_layout += '|';
			new_layout += e;
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

		layout = new_layout;
	}

	return new_layouts;
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


// crash due to have not check the validity of the entered data.
// avoid crash error
static const void*
GetMeshDataPtr(const aiMesh *mesh, const std::string &elem, size_t offset) {	
	const uint32_t channel = elem[2] - '0';
	const float *p = nullptr;
	switch (elem[0]) {
	// case 'p': p = &(mesh->mVertices[offset].x); break;
	// case 'n': p = &(mesh->mNormals[offset].x); break;
	// case 'T': p = &(mesh->mTangents[offset].x); break;
	// case 'b': p = &(mesh->mBitangents[offset].x); break;
	// case 'c': p = &(mesh->mColors[channel][offset].r); break;
	// case 't': p = &(mesh->mTextureCoords[channel][offset].x); break;
	case 'p':  //this is always present 
	    if(mesh->mVertices) { p = &(mesh->mVertices[offset].x); } break;
	case 'n':
		if( mesh->mNormals) { p = &(mesh->mNormals[offset].x); }  break;
	case 'T':
		if(mesh->mTangents) {	p = &(mesh->mTangents[offset].x); } break;
	case 'b':
		if(mesh->mBitangents) {	p = &(mesh->mBitangents[offset].x);  } break;
	case 'c':
		if(mesh->mColors && mesh->mColors[channel] ) { p = &(mesh->mColors[channel][offset].r); } break;
	case 't': 
		if(mesh->mTextureCoords && mesh->mTextureCoords[channel]) { p = &(mesh->mTextureCoords[channel][offset].x); } break;	
	case 'i':
	case 'w':
	default:
		printf("not support type in CopyMeshVertices, %d", elem[0]);
		break;
	}

	return p;
}

static void
CopyMeshVertices(const aiMesh *mesh, size_t startVB, const std::string &layout, buffer_ptr &buffer,aiMatrix4x4 &mTrans) {
	const size_t vertexSizeInBytes = CalcVertexSize(layout);	
	
	uint8_t *vertices = buffer.get() + startVB * vertexSizeInBytes;

	auto elems = AdjustLayoutElem(layout);
	for (uint32_t ii = 0; ii < mesh->mNumVertices; ++ii) {
		for (const auto& e : elems) {

			auto p = GetMeshDataPtr(mesh, e, ii);
			auto elemSizeInBytes = GetVertexElemSizeInBytes(e);
			//memcpy(vertices, p, elemSizeInBytes);
			if(e[0]=='p') {
				aiVector3D vec = *(aiVector3D*) p;
				aiVector3D o_vec = mTrans*vec;
				memcpy(vertices, &o_vec.x, elemSizeInBytes);
			}
			else if(e[0]=='n' && p ) {
				aiVector3D vec = *(aiVector3D*) p;
				aiVector3D o_vec = vec;            // could not need transfer 
				memcpy(vertices, &o_vec.x, elemSizeInBytes);
			}
			else if(e[0]=='T' && p ) {
				// crash ,this data will be invalid also.
				aiVector3D vec = *(aiVector3D*) p;
				aiVector3D o_vec = vec;
				memcpy(vertices, &o_vec.x, elemSizeInBytes);
			}
			else if(e[0]=='b'&& p ) {
				aiVector3D vec = *(aiVector3D*) p;
				aiVector3D o_vec = vec;
				memcpy(vertices, &o_vec.x, elemSizeInBytes);
			}
			else if(e[0]=='t' &&p ) {
				aiVector2D vec = *(aiVector2D*) p;
				memcpy(vertices, &vec.x, elemSizeInBytes);
			}
			else if(e[0]=='c' && p ) {
				// crash due to  color convert,may be some fbx color is not exist
				aiColor4D vec = *(aiColor4D*) p;
				memcpy(vertices, &vec.r, elemSizeInBytes);
			}
			vertices += elemSizeInBytes;
		}

	}
}

// vb 
// ib1，ib
static size_t
CopyMeshIndicesExt(const aiMesh *mesh, const load_config &config, int indexElementSize, size_t startIB,size_t startVB, ib_info &ib) {
	//const bool is32bit = (config.flags & load_config::IndexBuffer32Bit);
	// get elemSize from calcbuffersize'result for later check
	//const size_t elemSize = is32bit ? 4 : 2;
	const size_t elemSize = indexElementSize == 4 ? 4 : 2;    // avoid error
															  
	bool is32bit =  indexElementSize == 4 ? true : false;

	uint8_t *indices = ib.ibraw + startIB * elemSize;

	auto cp_op32 = [](const aiFace &face, uint8_t *&indices,size_t startVB) {
		const size_t sizeInBytes = face.mNumIndices * sizeof(uint32_t);
		// use corrent cast to avoid wrong memery usage
		uint32_t *uint32Indices = reinterpret_cast<uint32_t*>(indices);   
		for(int i= 0;i<face.mNumIndices;i++) {
			uint32_t  idx = startVB + face.mIndices[i];
			*uint32Indices ++ = idx;
		}
		//memcpy(indices, face.mIndices, sizeInBytes);
		indices += sizeInBytes;
	};
	auto cp_op16 = [](const aiFace &face, uint8_t *&indices,size_t startVB) {
		const size_t sizeInBytes = face.mNumIndices * sizeof(uint16_t);
		uint16_t *uint16Indices = reinterpret_cast<uint16_t*>(indices);
		for (uint32_t ii = 0; ii < face.mNumIndices; ++ii) {
			*uint16Indices++ = static_cast<uint16_t>(face.mIndices[ii]+startVB);
		}

		indices += sizeInBytes;
	};

	auto cp_op = is32bit ? cp_op32 : cp_op16;


	size_t numIndices = 0;
	for (uint32_t ii = 0; ii < mesh->mNumFaces; ++ii) {
		const auto& face = mesh->mFaces[ii];
		cp_op(face, indices,startVB);
		numIndices += face.mNumIndices;
	}

	return numIndices;
}

// 1. 前后配置继承
// 2. 索引类型16,32维护错误,旧的留存，已不用
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

bool hasRootNode(const aiNode *Node,int level) {
	  aiNode *node = Node->mParent;
		int  idx  = 1;
    while(node) {
			if(level == idx && node->mName== aiString("RootNode") )
			   return true;
			else if(level == idx && node->mName == aiString("RootNode"))
			   return true;
			else if(level == idx && node->mName == aiString("RootNode"))
			   return true;
	 		node = node->mParent;
			idx ++;
		}
		return false;
}

aiMatrix4x4 GetModelTransform( const aiNode * calcNode,bool avoid )
{
    // concatenate all parent transforms to get the global transform for this node
    aiMatrix4x4 mGlobalTransform = calcNode->mTransformation;
    aiNode* node = calcNode->mParent;
    while( node)
    {
		aiMatrix4x4 mParentTrans = node->mTransformation;
		if( hasRootNode(node,1) ) {
			mParentTrans = aiMatrix4x4();
		}
		else if( hasRootNode(node,2) )  {
			mParentTrans = aiMatrix4x4();
		}
		else {
			std::string strName = std::string( node->mName.C_Str());
			bool bIgnoreIdent = false;
			if(strName.find("_Geometric")!= std::string::npos) {
				bIgnoreIdent = true;                     // for assimp process
			}
			if(avoid && !bIgnoreIdent) {
				mParentTrans = aiMatrix4x4();
			}
		}

        mGlobalTransform = mParentTrans*mGlobalTransform ;    

        node = node->mParent;
	}
	return mGlobalTransform;
}

bool CalcualteTransform(const aiScene *scene,const aiNode *node,const aiMesh *mesh,aiMatrix4x4 &out_matrix,bool avoid)
{
	if(node) {
		for(int i=0;i<node->mNumMeshes;i++) {
			int meshIdx = node->mMeshes[i];
			if(scene->mMeshes[meshIdx] == mesh ) {
				out_matrix = GetModelTransform(node,avoid);
				return true;
			}
		}

		for(int i=0;i<node->mNumChildren;i++) {
			if(CalcualteTransform(scene,node->mChildren[i],mesh,out_matrix,avoid) )
			  return true;
		}
	}
	return false;
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

void CollectMesh(const aiScene *scene,const aiNode *node, MeshMaterialArray &mm )
{
	if(node) {
		if(node->mNumMeshes) {
			mm.resize( mm.size()+1 );
			MeshArray &meshes = mm[ mm.size()-1 ];
			for(int i=0;i<node->mNumMeshes;i++) {
				int meshIdx = node->mMeshes[i];
				aiMesh *mesh = scene->mMeshes[meshIdx];
				if(node->mName != mesh->mName) {
					printf("error: Mesh != Node\n");
				}
				//printf("MeshName = %s\n",mesh->mName.C_Str());		
				//printf("MeshIndex %d, MatIndex %d\n",meshIdx,mesh->mMaterialIndex);
				meshes.push_back(mesh);
			}
		}

		for(int i=0;i<node->mNumChildren;i++) {
			CollectMesh(scene,node->mChildren[i],mm);
		}
	}
}

// Material != Group
// MeshArray = mesh[] combine to one group
//   Group = primitive or primitives 
static void
SeparateMeshByNode(const aiScene *scene, MeshMaterialArray &mm) 
{
	CollectMesh(scene,scene->mRootNode,mm);
}

static void
LoadFBXMeshesByNode(const aiScene *scene, const load_config& config, mesh_data &md) {
	MeshMaterialArray mm;

	SeparateMeshByNode(scene,mm);

	md.groups.resize(mm.size());

	for (size_t ii = 0; ii < mm.size(); ++ii) {
		const auto &meshes = mm[ii];
		if (meshes.empty())
			continue;


		auto &group = md.groups[ii];
		auto &vb = group.vb;
		auto layouts = CreateVertexLayout(meshes.back(), config.layouts);
		for (const auto &layout : layouts) {

			size_t vertexSizeInBytes = 0, indexSizeInBytes = 0, indexElemSizeInBytes = 0;
			CalcBufferSize(meshes, layout, config, vertexSizeInBytes, indexSizeInBytes, indexElemSizeInBytes);

			int vertexElementSize = CalcVertexSize(layout);
			vb.num_vertices = vertexSizeInBytes / CalcVertexSize(layout);
			assert(vb.vbraws.find(layout) == vb.vbraws.end());
			// alloc vertex buffer
			vb.vbraws[layout] = make_buffer_ptr(vertexSizeInBytes);
			auto &buffer = vb.vbraws[layout];
			{
			}
			// alloc vertex buffer 
			auto &ib = group.ib;
			if (indexSizeInBytes != 0) {
				ib.ibraw = new uint8_t[indexSizeInBytes];
				ib.num_indices = indexSizeInBytes / indexElemSizeInBytes;
				ib.format = indexElemSizeInBytes == 4 ? 32 : 16;
				//config.flags |= load_config::IndexBuffer32Bit;  // set flag for later check
			}

			group.primitives.resize(meshes.size());

			size_t startVB = 0, startIB = 0;

			for (size_t jj = 0; jj < meshes.size(); ++jj) {
				const aiMesh *mesh = meshes[jj];                  //source sub mesh in group


				auto &primitive = group.primitives[jj];           //target sub primitive in group

				aiMatrix4x4 transform;
				CalcualteTransform(scene,scene->mRootNode,mesh,transform,true);

				//aiMatrix4x4 transform;
				//FindTransform(scene, scene->mRootNode, mesh, transform);

				//transformGlobal = aiMatrix4x4();  // disable vertices convert
				primitive.transform = *((glm::mat4x4*)(&transform));
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
				CopyMeshVertices(mesh, startVB, layout, buffer, transform );

				primitive.start_vertex = startVB;
				primitive.num_vertices = mesh->mNumVertices;

				// indices
				// avoid index error by check indexElementSize ,if config is not uniformity
				int globalVB = startVB;
				#ifdef __USE_LOCAL_INDEX
				globalVB = 0;
				#endif

				size_t meshIndicesCount = CopyMeshIndicesExt(mesh, config, indexElemSizeInBytes, startIB, globalVB, ib);
				primitive.start_index = startIB;
				primitive.num_indices = meshIndicesCount;

				#ifndef __USE_LOCAL_INDEX 
				startIB += meshIndicesCount;          
				#else 
				startIB = 0;
				#endif  

				startVB += mesh->mNumVertices;        // add VB inc avoid combine  error

				primitive.bounding.aabb.Init((const glm::vec3 *)mesh->mVertices, mesh->mNumVertices);
				primitive.bounding.sphere.Init(primitive.bounding.aabb);

				// reset center to origin 
				primitive.bounding.sphere.center.x = 0;
				primitive.bounding.sphere.center.y = 0;
				primitive.bounding.sphere.center.z = 0;

				group.bounding.Merge(primitive.bounding);

			}
		}
		md.bounding.Merge(group.bounding);
	}
}

// 定位的错误
// 1. copy vertices 没有处理合并，及索引int32/int16差别,(index 可以使用GlobalIndex/LocalIndex方式导出，当使用不同渲染API)
// 2. 非三角图元引发的崩溃
// 3. 有效数据没有检查引发崩溃
// 4. 按材质分类
//    丢失mesh（只读取一个大网格组的一小部分)，破坏 mesh 拓扑结构，同时又会成倍产生过多的拆分网格
// 5. 网格节点信息的使用(效果)
// 6. 加载参数(assimp 本身会修改变化的性质)
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
		auto layouts = CreateVertexLayout(meshes.back(), config.layouts);

		for (const auto &layout : layouts) {
			size_t vertexSizeInBytes = 0, indexSizeInBytes = 0, indexElemSizeInBytes = 0;
			CalcBufferSize(meshes, layout, config, vertexSizeInBytes, indexSizeInBytes, indexElemSizeInBytes);

			vb.num_vertices = vertexSizeInBytes / CalcVertexSize(layout);
			assert(vb.vbraws.find(layout) == vb.vbraws.end());
			
			vb.vbraws[layout] = make_buffer_ptr(vertexSizeInBytes);
			auto &buffer = vb.vbraws[layout];

			auto &ib = group.ib;

			if (indexSizeInBytes != 0) {
				ib.ibraw = new uint8_t[indexSizeInBytes];
				ib.num_indices = indexSizeInBytes / indexElemSizeInBytes;
				ib.format = indexElemSizeInBytes == 4 ? 32 : 16;
			}

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
				CopyMeshVertices(mesh, startVB, layout, buffer,transform);

				primitive.start_vertex = startVB;
				primitive.num_vertices = mesh->mNumVertices;

				startVB += mesh->mNumVertices;

				// indices
				size_t meshIndicesCount = CopyMeshIndices(mesh, config, startIB, ib);
				primitive.start_index = startIB;
				primitive.num_indices = meshIndicesCount;

				primitive.bounding.aabb.Init((const glm::vec3 *)mesh->mVertices, mesh->mNumVertices);
				primitive.bounding.sphere.Init(primitive.bounding.aabb);

				group.bounding.Merge(primitive.bounding);
			}			
		}

		md.bounding.Merge(group.bounding);
	}

}

static bool
SceneToMeshData(const aiScene *scene, const load_config &config, mesh_data &md) {
	LoadMaterials(scene, md.materials);
	LoadFBXMeshesByNode(scene,config,md);
	//LoadFBXMeshes(scene, config, md);

	return true;
}

bool
convertFBX(lua_State *L, const std::string &srcpath, const std::string &outputfile, const load_config &config) {
	uint32_t import_flags = 
		            aiProcessPreset_TargetRealtime_Fast |
							  //aiProcessPreset_TargetRealtime_MaxQuality 
							  aiProcess_FindDegenerates |
								aiProcess_FindInvalidData |
								aiProcess_OptimizeMeshes |
							 //| aiProcess_PreTransformVertices     //use this like in ue4 but ignore in unity 
							  //| aiProcess_ConvertToLeftHanded  		//use in worldspace,avoid composite error ,it's difference between world and local mode
						   0;

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
		luaL_error(L, "root not is invalid, source file : %s", srcpath.c_str());
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
