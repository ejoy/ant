#include "meshdata.h"
#include "utils.h"

extern "C" {
#include <lua.h>  
#include <lualib.h>
#include <lauxlib.h>
}

//bgfx include
#include <bx/string.h>
#include <bx/file.h>
#include <bgfx/bgfx.h>
#include <bgfx_utils.h>
#include <vertexdecl.h>
#include <../../3rdparty/ib-compress/indexbufferdecompression.h>

static void
LoadBGFXMesh(const std::string& filePath, mesh_data &md) {
#define BGFX_CHUNK_MAGIC_VB  BX_MAKEFOURCC('V', 'B', ' ', 0x1)
#define BGFX_CHUNK_MAGIC_IB  BX_MAKEFOURCC('I', 'B', ' ', 0x0)
#define BGFX_CHUNK_MAGIC_IBC BX_MAKEFOURCC('I', 'B', 'C', 0x0)
#define BGFX_CHUNK_MAGIC_PRI BX_MAKEFOURCC('P', 'R', 'I', 0x0)

	bx::FileReader reader;

	bx::open(&reader, filePath.c_str());

	uint32_t chunk;

	mesh_data::group group;
	while (4 == bx::read(&reader, chunk)) {
		switch (chunk) {
		case BGFX_CHUNK_MAGIC_VB: {
			auto &bounding = group.bounding;
			bx::read(&reader, bounding.sphere);
			bx::read(&reader, bounding.aabb);
			glm::mat4x4 obb;
			bx::read(&reader, obb);

			bgfx::VertexDecl decl;
			bgfx::read(&reader, decl);
			auto &vb = group.vb;

			const auto layout = GenVBLayoutFromDecl(decl);

			uint16_t stride = decl.getStride();
			uint16_t numVertices;
			bx::read(&reader, numVertices);
			vb.num_vertices = numVertices;
			const uint32_t vertexSizeInBytes = numVertices * stride;
			auto buffer = make_buffer_ptr(vertexSizeInBytes);
			
			bx::read(&reader, buffer.get(), vertexSizeInBytes);
			vb.vbraws[layout] = std::move(buffer);
		}
		break;

		case BGFX_CHUNK_MAGIC_IB: {
			uint32_t numIndices;
			bx::read(&reader, numIndices);
			auto &ib = group.ib;
			ib.num_indices = numIndices;
			ib.format = 16;
			const uint32_t sizeInBytes = numIndices * 2;	// bgfx assume only use uint16_t type to save indices
			ib.ibraw = new uint8_t[sizeInBytes];
			bx::read(&reader, ib.ibraw, sizeInBytes);
		}
								  break;
		case BGFX_CHUNK_MAGIC_IBC: {
			uint32_t numIndices;
			bx::read(&reader, numIndices);
			auto &ib = group.ib;
			ib.ibraw = new uint8_t[numIndices * 2];

			uint32_t compressedSize;
			bx::read(&reader, compressedSize);

			std::vector<uint8_t> compressedIndices(compressedSize);
			bx::read(&reader, &compressedIndices[0], compressedSize);

			ReadBitstream rbs(compressedIndices.data(), compressedSize);
			DecompressIndexBuffer((uint16_t*)ib.ibraw, numIndices / 3, rbs);
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
		auto &vb = g.vb;
		auto &vbraws = vb.vbraws;
		assert(vbraws.size() == 1);
		const auto &oldlayout = vbraws.begin()->first;
		auto newlayout = oldlayout;
		newlayout += "|T30nIf";
		newlayout += "|b30nIf";

		auto dstdecl = GenVertexDeclFromVBLayout(newlayout);
		auto srcdecl = GenVertexDeclFromVBLayout(oldlayout);

		auto stride = dstdecl.getStride();
		auto sizeInBytes = vb.num_vertices * stride;

		auto buffer = make_buffer_ptr(sizeInBytes);

		assert(vb.vbraws.size() == 1);
		const auto &first = *vb.vbraws.cbegin();		
		auto &oldbuffer = first.second;

		bgfx::vertexConvert(dstdecl, buffer.get(), srcdecl, oldbuffer.get(), uint32_t(vb.num_vertices));

		auto &ib = g.ib;
		if (ib.format == 32) {
			std::vector<uint16_t> u16buffer(ib.num_indices);

			convert_32bit_to_16bit((const uint32_t*)ib.ibraw, &u16buffer[0], uint32_t(ib.num_indices));
			calcTangents(buffer.get(), uint32_t(vb.num_vertices), dstdecl, &u16buffer[0], uint32_t(ib.num_indices));
		} else {
			calcTangents(buffer.get(), uint32_t(vb.num_vertices), dstdecl, (const uint16_t*)ib.ibraw, uint32_t(ib.num_indices));
		}

		vb.vbraws.erase(vb.vbraws.find(oldlayout));
		vb.vbraws[newlayout] = std::move(buffer);
	}
};

static void flip_uv(mesh_data &md) {
	for (auto &g : md.groups) {
		auto &vb = g.vb;
		auto &vbraws = vb.vbraws;
		assert(vbraws.size() == 1);
		const auto &layout = vbraws.begin()->first;
		auto &buffer = vbraws[layout];
		auto decl = GenVertexDeclFromVBLayout(layout);

		for (auto ii = 0; ii < 8; ++ii) {
			bgfx::Attrib::Enum a = bgfx::Attrib::Enum(bgfx::Attrib::TexCoord0 + ii);
			if (decl.has(a)) {
				for (auto iv = 0; iv < vb.num_vertices; ++iv) {
					float output[4];
					const auto &buf = vb.vbraws.cbegin()->second;
					bgfx::vertexUnpack(output, a, decl, buffer.get(), iv);

					output[1] = -output[1];

					uint8_t num;
					bgfx::AttribType::Enum type;
					bool normalize, asInt;
					decl.decode(a, num, type, normalize, asInt);
					bgfx::vertexPack(output, normalize, a, decl, buffer.get(), iv);
				}

			}
		}

	}

}

bool
convertBGFX(lua_State *L, const std::string &srcpath, const std::string &outputfile, const load_config &config) {
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

	if (config.NeedCreateTangentSpaceData()) {
		calc_tangents(md);
	}

	if (config.NeedFlipUV()) {
		flip_uv(md);
	}

	if (!WriteMeshData(md, srcpath, outputfile)) {
		luaL_error(L, "save to mesh file : %s failed!", outputfile.c_str());
		return false;
	}

	return true;
}