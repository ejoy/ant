#define LUA_LIB

extern "C" {
#include <lua.h>
#include <lauxlib.h>
}

#include <bgfx/c99/bgfx.h>
#include <imgui.h>
#include <algorithm>
#include <glm/glm.hpp>
#include <glm/ext/matrix_clip_space.hpp>
#include <cstring>
#include <cstdlib>
#include <malloc.h>
#include "bgfx_interface.h"
#include "luabgfx.h"

#define IMGUI_FLAGS_NONE        UINT8_C(0x00)
#define IMGUI_FLAGS_FONT        UINT8_C(0x01)


void init_ime(void* window);
void init_cursor();
void set_cursor(ImGuiMouseCursor cursor);
void update_mousepos();
struct context {
	void render(ImDrawData* drawData) {
		const ImGuiIO& io = ImGui::GetIO();
		const float width = io.DisplaySize.x;
		const float height = io.DisplaySize.y;
		const float fb_width = io.DisplaySize.x * drawData->FramebufferScale.x;
		const float fb_height = io.DisplaySize.y * drawData->FramebufferScale.y;

		BGFX(set_view_name)(m_viewId, "ImGui");
		BGFX(set_view_mode)(m_viewId, BGFX_VIEW_MODE_SEQUENTIAL);

		const bgfx_caps_t* caps = BGFX(get_caps)();
		auto ortho = caps->homogeneousDepth
			? glm::orthoLH_NO(0.0f, width, height, 0.0f, 0.0f, 1000.0f)
			: glm::orthoLH_ZO(0.0f, width, height, 0.0f, 0.0f, 1000.0f)
			;
		BGFX(set_view_transform)(m_viewId, NULL, (const void*)& ortho[0]);
		BGFX(set_view_rect)(m_viewId, 0, 0, uint16_t(fb_width), uint16_t(fb_height));

		ImVec2 clip_off = drawData->DisplayPos;
		ImVec2 clip_scale = drawData->FramebufferScale;

		for (int32_t ii = 0, num = drawData->CmdListsCount; ii < num; ++ii) {
			const ImDrawList* drawList = drawData->CmdLists[ii];
			uint32_t numVertices = (uint32_t)drawList->VtxBuffer.size();
			uint32_t numIndices = (uint32_t)drawList->IdxBuffer.size();

			if (numVertices != BGFX(get_avail_transient_vertex_buffer)(numVertices, &m_layout)
				|| numIndices != BGFX(get_avail_transient_index_buffer)(numIndices)) {
				break;
			}

			bgfx_transient_vertex_buffer_t tvb;
			bgfx_transient_index_buffer_t tib;
			BGFX(alloc_transient_vertex_buffer)(&tvb, numVertices, &m_layout);
			BGFX(alloc_transient_index_buffer)(&tib, numIndices);
			ImDrawVert* verts = (ImDrawVert*)tvb.data;
			memcpy(verts, drawList->VtxBuffer.begin(), numVertices * sizeof(ImDrawVert));
			ImDrawIdx* indices = (ImDrawIdx*)tib.data;
			memcpy(indices, drawList->IdxBuffer.begin(), numIndices * sizeof(ImDrawIdx));

			uint32_t offset = 0;
			for (const ImDrawCmd& cmd : drawList->CmdBuffer) {
				if (cmd.UserCallback) {
					cmd.UserCallback(drawList, &cmd);
					offset += cmd.ElemCount;
					continue;
				}
				if (0 == cmd.ElemCount) {
					continue;
				}
				assert(NULL != cmd.TextureId);
				union { ImTextureID ptr; struct { bgfx_texture_handle_t handle; uint8_t flags; uint8_t mip; } s; } texture = { cmd.TextureId };

				ImVec4 clip_rect;
				clip_rect.x = (cmd.ClipRect.x - clip_off.x) * clip_scale.x;
				clip_rect.y = (cmd.ClipRect.y - clip_off.y) * clip_scale.y;
				clip_rect.z = (cmd.ClipRect.z - clip_off.x) * clip_scale.x;
				clip_rect.w = (cmd.ClipRect.w - clip_off.y) * clip_scale.y;

				const uint16_t xx = uint16_t(std::max(clip_rect.x, 0.0f));
				const uint16_t yy = uint16_t(std::max(clip_rect.y, 0.0f));
				BGFX(set_scissor)(xx, yy
					, uint16_t(std::min(clip_rect.z, 65535.0f) - xx)
					, uint16_t(std::min(clip_rect.w, 65535.0f) - yy)
					);

				uint64_t state = 0
					| BGFX_STATE_WRITE_RGB
					| BGFX_STATE_WRITE_A
					| BGFX_STATE_MSAA
					| BGFX_STATE_BLEND_FUNC(BGFX_STATE_BLEND_SRC_ALPHA, BGFX_STATE_BLEND_INV_SRC_ALPHA)
					;
				BGFX(set_state)(state, 0);

				BGFX(set_transient_vertex_buffer)(0, &tvb, 0, numVertices);
				BGFX(set_transient_index_buffer)(&tib, offset, cmd.ElemCount);
				if (IMGUI_FLAGS_FONT & texture.s.flags) {
					BGFX(set_texture)(0, s_fontTex, texture.s.handle, UINT32_MAX);
					BGFX(submit)(m_viewId, m_fontProgram, 0, false);
				}
				else {
					BGFX(set_texture)(0, s_imageTex, texture.s.handle, UINT32_MAX);
					BGFX(submit)(m_viewId, m_imageProgram, 0, false);
				}
				offset += cmd.ElemCount;
			}
		}
	}

	void create() {
		BGFX(vertex_layout_begin)(&m_layout, BGFX_RENDERER_TYPE_NOOP);
		BGFX(vertex_layout_add)(&m_layout, BGFX_ATTRIB_POSITION, 2, BGFX_ATTRIB_TYPE_FLOAT, false, false);
		BGFX(vertex_layout_add)(&m_layout, BGFX_ATTRIB_TEXCOORD0, 2, BGFX_ATTRIB_TYPE_FLOAT, false, false);
		BGFX(vertex_layout_add)(&m_layout, BGFX_ATTRIB_COLOR0, 4, BGFX_ATTRIB_TYPE_UINT8, true, false);
		BGFX(vertex_layout_end)(&m_layout);
	}

	bgfx_view_id_t        m_viewId;
	bgfx_vertex_layout_t  m_layout;
	bgfx_program_handle_t m_fontProgram;
	bgfx_program_handle_t m_imageProgram;
	bgfx_uniform_handle_t s_fontTex;
	bgfx_uniform_handle_t s_imageTex;
};

static context s_ctx;


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
lgetMemory(lua_State* L) {
	lua_pushinteger(L, allocator_memory);
	return 1;
}

static int
lcreate(lua_State* L) {
	ImGui::CreateContext();
	ImGuiIO& io = ImGui::GetIO();
	io.IniFilename = NULL;
	init_ime(lua_touserdata(L, 1));
	init_cursor();
	s_ctx.create();
	return 0;
}

static int
ldestroy(lua_State* L) {
	ImGui::DestroyContext();
	return 0;
}

static int
lviewId(lua_State* L) {
	if (lua_isnoneornil(L, 1)) {
		lua_pushinteger(L, s_ctx.m_viewId);
		return 1;
	}
	s_ctx.m_viewId = (bgfx_view_id_t)lua_tointeger(L, 1);
	return 0;
}


static int
lfontProgram(lua_State* L) {
	s_ctx.m_fontProgram = bgfx_program_handle_t{ BGFX_LUAHANDLE_ID(PROGRAM, (int)luaL_checkinteger(L, 1)) };
	s_ctx.s_fontTex = bgfx_uniform_handle_t{ BGFX_LUAHANDLE_ID(UNIFORM, (int)luaL_checkinteger(L, 2)) };
	return 0;
}

static int
limageProgram(lua_State* L) {
	s_ctx.m_imageProgram = bgfx_program_handle_t{ BGFX_LUAHANDLE_ID(PROGRAM, (int)luaL_checkinteger(L, 1)) };
	s_ctx.s_imageTex = bgfx_uniform_handle_t{ BGFX_LUAHANDLE_ID(UNIFORM, (int)luaL_checkinteger(L, 2)) };
	return 0;
}

int buildFont(lua_State *L) {
	ImFontAtlas* atlas = ImGui::GetIO().Fonts;
	uint8_t* data;
	int32_t width;
	int32_t height;
	atlas->GetTexDataAsAlpha8(&data, &width, &height);

	union { ImTextureID ptr; struct { bgfx_texture_handle_t handle; uint8_t flags; uint8_t mip; } s; } texture;
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
	texture.s.mip = 0;
	atlas->TexID = texture.ptr;
	atlas->ClearInputData();
	atlas->ClearTexData();
	return 0;
}

int
beginFrame(lua_State* L) {
	ImGuiIO& io = ImGui::GetIO();
	io.DeltaTime = (float)luaL_checknumber(L, 1);

	ImGuiMouseCursor cursor_type = io.MouseDrawCursor
		? ImGuiMouseCursor_None
		: ImGui::GetMouseCursor();
#if defined(_WIN32)
	update_mousepos();
#endif
	if (io.Fonts->Fonts.Size == 0) {
		ImFontConfig config;
		config.SizePixels = 18.0f;
		io.Fonts->AddFontDefault(&config);
		buildFont(L);
	}

	ImGui::NewFrame();

	if (io.WantCaptureMouse && !(io.ConfigFlags & ImGuiConfigFlags_NoMouseCursorChange)) {
		set_cursor(cursor_type);
	}
	return 0;
}

int
endFrame(lua_State* L) {
	ImGui::Render();
	s_ctx.render(ImGui::GetDrawData());
	return 0;
}

ImTextureID
luahandle_to_texture_id(lua_State* L, int lua_handle) {
	bgfx_texture_handle_t th = { BGFX_LUAHANDLE_ID(TEXTURE, lua_handle) };
	union { struct { bgfx_texture_handle_t handle; uint8_t flags; uint8_t mip; } s; ImTextureID ptr; } texture;
	texture.s.handle = th;
	texture.s.flags = 0;
	texture.s.mip = 0;
	return texture.ptr;
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
		{ "create", lcreate },
		{ "destroy", ldestroy },
		{ "get_memory", lgetMemory },
		{ "viewid", lviewId },
		{ "font_program", lfontProgram },
		{ "image_program", limageProgram },
		{NULL,NULL}
	};
	luaopen_imgui(L);
	luaL_newlib(L, l);
	luaL_setfuncs(L,l,0);
	lua_setfield(L, -2, "ant");
	return 1;
}
