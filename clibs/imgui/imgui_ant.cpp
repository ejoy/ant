#define LUA_LIB

#include "imgui_ant.h"
#include <algorithm>
#include <glm/glm.hpp>
#include <glm/ext/matrix_clip_space.hpp>
#include <cstring>
#include <cstdlib>
#include <malloc.h>
#include "bgfx_interface.h"
#include "luabgfx.h"

void init_ime(void* window);
void init_cursor();
void set_cursor(ImGuiMouseCursor cursor);
void update_mousepos();

#if BX_PLATFORM_WINDOWS
#define bx_malloc_size _msize
#elif BX_PLATFORM_LINUX
#define bx_malloc_size malloc_usable_size
#elif BX_PLATFORM_OSX
#define bx_malloc_size malloc_size
#elif BX_PLATFORM_IOS
#define bx_malloc_size malloc_size
#else
#    error "Unknown PLATFORM!"
#endif

int64_t allocator_memory = 0;

static void* ImGuiAlloc(size_t sz, void* /*user_data*/) {
	void* ptr = malloc(sz);
	if (ptr) {
		allocator_memory += bx_malloc_size(ptr);
	}
	return ptr;
}

static void ImGuiFree(void* ptr, void* /*user_data*/) {
	if (ptr) {
		allocator_memory -= bx_malloc_size(ptr);
	}
	free(ptr);
}

static int
lmemory(lua_State* L) {
	lua_pushinteger(L, allocator_memory);
	return 1;
}

namespace plat {
	void CreateContext(lua_State* L) {
		context* ctx = new context;
		ImGuiIO& io = ImGui::GetIO();
		io.IniFilename = NULL;
		io.UserData = ctx;
		init_ime(lua_touserdata(L, 1));
		init_cursor();
		ctx->L = L;
		BGFX(vertex_layout_begin)(&ctx->m_layout, BGFX_RENDERER_TYPE_NOOP);
		BGFX(vertex_layout_add)(&ctx->m_layout, BGFX_ATTRIB_POSITION, 2, BGFX_ATTRIB_TYPE_FLOAT, false, false);
		BGFX(vertex_layout_add)(&ctx->m_layout, BGFX_ATTRIB_TEXCOORD0, 2, BGFX_ATTRIB_TYPE_FLOAT, false, false);
		BGFX(vertex_layout_add)(&ctx->m_layout, BGFX_ATTRIB_COLOR0, 4, BGFX_ATTRIB_TYPE_UINT8, true, false);
		BGFX(vertex_layout_end)(&ctx->m_layout);
	}

	void DestroyContext(lua_State* L) {
		context* ctx = (context*)ImGui::GetIO().UserData;
		delete ctx;
	}

	void NewFrame(lua_State* L) {
		ImGuiIO& io = ImGui::GetIO();
		io.DeltaTime = (float)luaL_checknumber(L, 1);
#if defined(_WIN32)
		update_mousepos();
#endif
		ImGuiMouseCursor cursor_type = io.MouseDrawCursor ? ImGuiMouseCursor_None : ImGui::GetMouseCursor();
		if (io.WantCaptureMouse && !(io.ConfigFlags & ImGuiConfigFlags_NoMouseCursorChange)) {
			set_cursor(cursor_type);
		}
	}

	constexpr uint16_t IMGUI_FLAGS_NONE = 0x00;
	constexpr uint16_t IMGUI_FLAGS_FONT = 0x01;
	union ImGuiTexture {
		ImTextureID ptr;
		struct {
			bgfx_texture_handle_t handle;
			uint16_t flags;
		} s;
	};

	void Render(lua_State* L) {
		context* ctx = (context*)ImGui::GetIO().UserData;
		ImDrawData* drawData = ImGui::GetDrawData();
		const ImVec2& clip_size = drawData->DisplaySize;
		const ImVec2& clip_offset = drawData->DisplayPos;
		const ImVec2& clip_scale = drawData->FramebufferScale;

		BGFX(set_view_name)(ctx->m_viewId, "ImGui");
		BGFX(set_view_mode)(ctx->m_viewId, BGFX_VIEW_MODE_SEQUENTIAL);

		const bgfx_caps_t* caps = BGFX(get_caps)();
		auto ortho = caps->homogeneousDepth
			? glm::orthoLH_NO(0.0f, clip_size.x, clip_size.y, 0.0f, 0.0f, 1000.0f)
			: glm::orthoLH_ZO(0.0f, clip_size.x, clip_size.y, 0.0f, 0.0f, 1000.0f)
			;
		BGFX(set_view_transform)(ctx->m_viewId, NULL, (const void*)&ortho[0]);

		const float fb_width = clip_size.x * clip_scale.x;
		const float fb_height = clip_size.y * clip_scale.y;
		BGFX(set_view_rect)(ctx->m_viewId, 0, 0, uint16_t(fb_width), uint16_t(fb_height));

		for (size_t ii = 0, num = drawData->CmdListsCount; ii < num; ++ii) {
			const ImDrawList* drawList = drawData->CmdLists[ii];
			uint32_t numVertices = (uint32_t)drawList->VtxBuffer.size();
			uint32_t numIndices = (uint32_t)drawList->IdxBuffer.size();

			if (numVertices != BGFX(get_avail_transient_vertex_buffer)(numVertices, &ctx->m_layout)
				|| numIndices != BGFX(get_avail_transient_index_buffer)(numIndices)) {
				break;
			}

			bgfx_transient_vertex_buffer_t tvb;
			bgfx_transient_index_buffer_t tib;
			BGFX(alloc_transient_vertex_buffer)(&tvb, numVertices, &ctx->m_layout);
			BGFX(alloc_transient_index_buffer)(&tib, numIndices);
			ImDrawVert* verts = (ImDrawVert*)tvb.data;
			memcpy(verts, drawList->VtxBuffer.begin(), numVertices * sizeof(ImDrawVert));
			ImDrawIdx* indices = (ImDrawIdx*)tib.data;
			memcpy(indices, drawList->IdxBuffer.begin(), numIndices * sizeof(ImDrawIdx));

			uint32_t offset = 0;
			for (const ImDrawCmd& cmd : drawList->CmdBuffer) {
				if (0 == cmd.ElemCount) {
					continue;
				}
				assert(NULL != cmd.TextureId);
				ImGuiTexture texture = { cmd.TextureId };

				const float x = (cmd.ClipRect.x - clip_offset.x) * clip_scale.x;
				const float y = (cmd.ClipRect.y - clip_offset.y) * clip_scale.y;
				const float w = (cmd.ClipRect.z - cmd.ClipRect.x) * clip_scale.x;
				const float h = (cmd.ClipRect.w - cmd.ClipRect.y) * clip_scale.y;
				BGFX(set_scissor)(
					  uint16_t(std::min(std::max(x, 0.0f), 65535.0f))
					, uint16_t(std::min(std::max(y, 0.0f), 65535.0f))
					, uint16_t(std::min(std::max(w, 0.0f), 65535.0f))
					, uint16_t(std::min(std::max(h, 0.0f), 65535.0f))
					);

				constexpr uint64_t state = 0
					| BGFX_STATE_WRITE_RGB
					| BGFX_STATE_WRITE_A
					| BGFX_STATE_MSAA
					| BGFX_STATE_BLEND_FUNC(BGFX_STATE_BLEND_SRC_ALPHA, BGFX_STATE_BLEND_INV_SRC_ALPHA)
					;
				BGFX(set_state)(state, 0);

				BGFX(set_transient_vertex_buffer)(0, &tvb, 0, numVertices);
				BGFX(set_transient_index_buffer)(&tib, offset, cmd.ElemCount);
				if (IMGUI_FLAGS_FONT == texture.s.flags) {
					BGFX(set_texture)(0, ctx->s_fontTex, texture.s.handle, UINT32_MAX);
					BGFX(submit)(ctx->m_viewId, ctx->m_fontProgram, 0, BGFX_DISCARD_TEXTURE_SAMPLERS);
				}
				else {
					BGFX(set_texture)(0, ctx->s_imageTex, texture.s.handle, UINT32_MAX);
					BGFX(submit)(ctx->m_viewId, ctx->m_imageProgram, 0, BGFX_DISCARD_TEXTURE_SAMPLERS);
				}
				offset += cmd.ElemCount;
			}
		}
	}

	int BuildFont(lua_State* L) {
		ImFontAtlas* atlas = ImGui::GetIO().Fonts;
		uint8_t* data;
		int32_t width;
		int32_t height;
		atlas->GetTexDataAsAlpha8(&data, &width, &height);

		ImGuiTexture texture;
		texture.s.handle = BGFX(create_texture_2d)(
			(uint16_t)width
			, (uint16_t)height
			, false
			, 1
			, BGFX_TEXTURE_FORMAT_A8
			, 0
			, BGFX(copy)(data, width * height)
			);
		texture.s.flags = IMGUI_FLAGS_FONT;
		atlas->TexID = texture.ptr;
		atlas->ClearInputData();
		atlas->ClearTexData();
		return 0;
	}

	ImTextureID GetTextureID(lua_State* L, int lua_handle) {
		bgfx_texture_handle_t th = { BGFX_LUAHANDLE_ID(TEXTURE, lua_handle) };
		ImGuiTexture texture;
		texture.s.handle = th;
		texture.s.flags = IMGUI_FLAGS_NONE;
		return texture.ptr;
	}

	static int viewId(lua_State* L) {
		context* ctx = (context*)ImGui::GetIO().UserData;
		if (lua_isnoneornil(L, 1)) {
			lua_pushinteger(L, ctx->m_viewId);
			return 1;
		}
		ctx->m_viewId = (bgfx_view_id_t)lua_tointeger(L, 1);
		return 0;
	}

	static int fontProgram(lua_State* L) {
		context* ctx = (context*)ImGui::GetIO().UserData;
		ctx->m_fontProgram = bgfx_program_handle_t{ BGFX_LUAHANDLE_ID(PROGRAM, (int)luaL_checkinteger(L, 1)) };
		ctx->s_fontTex = bgfx_uniform_handle_t{ BGFX_LUAHANDLE_ID(UNIFORM, (int)luaL_checkinteger(L, 2)) };
		return 0;
	}

	static int imageProgram(lua_State* L) {
		context* ctx = (context*)ImGui::GetIO().UserData;
		ctx->m_imageProgram = bgfx_program_handle_t{ BGFX_LUAHANDLE_ID(PROGRAM, (int)luaL_checkinteger(L, 1)) };
		ctx->s_imageTex = bgfx_uniform_handle_t{ BGFX_LUAHANDLE_ID(UNIFORM, (int)luaL_checkinteger(L, 2)) };
		return 0;
	}
}

extern "C" int luaopen_imgui(lua_State* L);

extern "C"
#if defined(_WIN32)
__declspec(dllexport)
#endif
int
luaopen_imgui_ant(lua_State* L) {
	luaL_checkversion(L);
	init_interface(L);
	ImGui::SetAllocatorFunctions(&ImGuiAlloc, &ImGuiFree, NULL);
	luaL_Reg l[] = {
		{ "memory", lmemory },
		{ "viewid", plat::viewId },
		{ "font_program", plat::fontProgram },
		{ "image_program", plat::imageProgram },
		{NULL,NULL}
	};
	luaopen_imgui(L);
	luaL_newlib(L, l);
	luaL_setfuncs(L,l,0);
	lua_setfield(L, -2, "ant");
	return 1;
}
