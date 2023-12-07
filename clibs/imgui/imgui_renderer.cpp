#include <imgui.h>
#include <lua.hpp>
#include <algorithm>
#include <glm/glm.hpp>
#include <glm/ext/matrix_clip_space.hpp>
#include <cstring>
#include <cstdlib>
#include <stdlib.h>
#include <stack>
#include "bgfx_interface.h"
#include "luabgfx.h"
#include "imgui_window.h"
#include "imgui_platform.h"

struct RendererViewport {
	int viewid = -1;
	bgfx_frame_buffer_handle_t fb = BGFX_INVALID_HANDLE;
};

enum class RendererTextureType: uint16_t {
	Font,
	Image,
};

union RendererTexture {
	ImTextureID id;
	struct {
		bgfx_texture_handle_t handle;
		RendererTextureType type;
	} s;
};
static_assert(sizeof(ImTextureID) == sizeof(RendererTexture));

std::stack<int> g_viewIdPool;
bgfx_vertex_layout_t  g_layout;
bgfx_program_handle_t g_fontProgram;
bgfx_program_handle_t g_imageProgram;
bgfx_uniform_handle_t g_fontTex;
bgfx_uniform_handle_t g_imageTex;


void rendererDrawData(ImGuiViewport* viewport) {
	RendererViewport* ud = (RendererViewport*)viewport->RendererUserData;
	const ImDrawData* drawData = viewport->DrawData;
	const ImVec2& clip_size = drawData->DisplaySize;
	const ImVec2 clip_offset = drawData->DisplayPos;
	const ImVec2& clip_scale = drawData->FramebufferScale;

	bgfx_encoder_t* encoder = BGFX(encoder_begin)(false);
	BGFX(set_view_name)(ud->viewid, "ImGui");
	BGFX(set_view_mode)(ud->viewid, BGFX_VIEW_MODE_SEQUENTIAL);

	float L = drawData->DisplayPos.x;
	float R = drawData->DisplayPos.x + drawData->DisplaySize.x;
	float T = drawData->DisplayPos.y;
	float B = drawData->DisplayPos.y + drawData->DisplaySize.y;
	const bgfx_caps_t* caps = BGFX(get_caps)();
	auto ortho = caps->homogeneousDepth
		? glm::orthoLH_NO(L, R, B, T, 0.0f, 1000.0f)
		: glm::orthoLH_ZO(L, R, B, T, 0.0f, 1000.0f)
		;
	BGFX(set_view_transform)(ud->viewid, NULL, (const void*)&ortho[0]);

	const float fb_x = 0;
	const float fb_y = 0;
	const float fb_w = fb_x + clip_size.x * clip_scale.x;
	const float fb_h = fb_y + clip_size.y * clip_scale.y;
	BGFX(set_view_rect)(ud->viewid, uint16_t(fb_x), uint16_t(fb_y), uint16_t(fb_w), uint16_t(fb_h));

	for (size_t ii = 0, num = drawData->CmdListsCount; ii < num; ++ii) {
		const ImDrawList* drawList = drawData->CmdLists[(int)ii];
		uint32_t numVertices = (uint32_t)drawList->VtxBuffer.size();
		uint32_t numIndices = (uint32_t)drawList->IdxBuffer.size();

		if (numVertices != BGFX(get_avail_transient_vertex_buffer)(numVertices, &g_layout)
			|| numIndices != BGFX(get_avail_transient_index_buffer)(numIndices, false)) {
			break;
		}

		bgfx_transient_vertex_buffer_t tvb;
		bgfx_transient_index_buffer_t tib;
		BGFX(alloc_transient_vertex_buffer)(&tvb, numVertices, &g_layout);
		BGFX(alloc_transient_index_buffer)(&tib, numIndices, false);
		ImDrawVert* verts = (ImDrawVert*)tvb.data;
		memcpy(verts, drawList->VtxBuffer.begin(), numVertices * sizeof(ImDrawVert));
		ImDrawIdx* indices = (ImDrawIdx*)tib.data;
		memcpy(indices, drawList->IdxBuffer.begin(), numIndices * sizeof(ImDrawIdx));

		for (const ImDrawCmd& cmd : drawList->CmdBuffer) {
			if (0 == cmd.ElemCount) {
				continue;
			}
			ImTextureID texid = cmd.GetTexID();
			assert(NULL != texid);
			RendererTexture texture;
			texture.id = texid;

			const float x = (cmd.ClipRect.x - clip_offset.x) * clip_scale.x;
			const float y = (cmd.ClipRect.y - clip_offset.y) * clip_scale.y;
			const float w = (cmd.ClipRect.z - cmd.ClipRect.x) * clip_scale.x;
			const float h = (cmd.ClipRect.w - cmd.ClipRect.y) * clip_scale.y;
			
			BGFX(encoder_set_scissor)(encoder
				, uint16_t(std::min(std::max(x, 0.0f), 65535.0f))
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
			BGFX(encoder_set_state)(encoder, state, 0);

			BGFX(encoder_set_transient_vertex_buffer)(encoder, 0, &tvb, cmd.VtxOffset, numVertices);
			BGFX(encoder_set_transient_index_buffer)(encoder, &tib, cmd.IdxOffset, cmd.ElemCount);
			if (texture.s.type == RendererTextureType::Font) {
				BGFX(encoder_set_texture)(encoder, 0, g_fontTex, texture.s.handle, UINT32_MAX);
				BGFX(encoder_submit)(encoder, ud->viewid, g_fontProgram, 0, BGFX_DISCARD_STATE);
			}
			else {
				BGFX(encoder_set_texture)(encoder, 0, g_imageTex, texture.s.handle, UINT32_MAX);
				BGFX(encoder_submit)(encoder, ud->viewid, g_imageProgram, 0, BGFX_DISCARD_STATE);
			}
		}
	}
	BGFX(encoder_discard)(encoder, BGFX_DISCARD_ALL);
	BGFX(encoder_end)(encoder);
}

static int rendererGetViewId() {
	return window_event_viewid();
}
 
static void rendererFreeViewId(int viewid) {
	g_viewIdPool.push(viewid);
}

static int rendererAllocViewId() {
	if (g_viewIdPool.empty()) {
		return rendererGetViewId();
	}
	int viewid = g_viewIdPool.top();
	g_viewIdPool.pop();
	return viewid;
}

static void rendererCreateWindow(ImGuiViewport* viewport) {
	int viewid = rendererAllocViewId();
	if (viewid == -1) {
		return;
	}
	bgfx_frame_buffer_handle_t fb = BGFX(create_frame_buffer_from_nwh)(
		platformGetHandle(viewport),
		(uint16_t)viewport->Size.x,
		(uint16_t)viewport->Size.y,
		BGFX_TEXTURE_FORMAT_RGBA8,
		BGFX_TEXTURE_FORMAT_D24S8
		);
	if (!BGFX_HANDLE_IS_VALID(fb)) {
		rendererFreeViewId(viewid);
		return;
	}
	RendererViewport* ud = new RendererViewport;
	viewport->RendererUserData = ud;
	ud->viewid = viewid;
	ud->fb = fb;
	BGFX(set_view_frame_buffer)(ud->viewid, fb);
}

static void rendererDestroyWindow(ImGuiViewport* viewport) {
	RendererViewport* ud = (RendererViewport*)viewport->RendererUserData;
	if (ud) {
		if (!BGFX_HANDLE_IS_VALID(ud->fb)) {
			BGFX(destroy_frame_buffer)(ud->fb);
		}
		if (ud->viewid != -1) {
			rendererFreeViewId(ud->viewid);
		}
		delete ud;
		viewport->RendererUserData = nullptr;
	}
}

static void rendererSetWindowSize(ImGuiViewport* viewport, ImVec2 size) {
	RendererViewport* ud = (RendererViewport*)viewport->RendererUserData;
	bgfx_frame_buffer_handle_t fb = BGFX(create_frame_buffer_from_nwh)(
		platformGetHandle(viewport),
		(uint16_t)size.x,
		(uint16_t)size.y,
		BGFX_TEXTURE_FORMAT_RGBA8,
		BGFX_TEXTURE_FORMAT_D24S8
		);
	if (!BGFX_HANDLE_IS_VALID(fb)) {
		return;
	}
	BGFX(destroy_frame_buffer)(ud->fb);
	BGFX(set_view_frame_buffer)(ud->viewid, fb);
	ud->fb = fb;
}

static void rendererRenderWindow(ImGuiViewport* viewport, void*) {
	rendererDrawData(viewport);
}

static void rendererSwapBuffers(ImGuiViewport* viewport, void*) {
}

bool rendererCreate() {
	ImGuiIO& io = ImGui::GetIO();
	io.BackendFlags |= ImGuiBackendFlags_RendererHasViewports;

	ImGuiPlatformIO& platform_io = ImGui::GetPlatformIO();
	platform_io.Renderer_CreateWindow = rendererCreateWindow;
	platform_io.Renderer_DestroyWindow = rendererDestroyWindow;
	platform_io.Renderer_SetWindowSize = rendererSetWindowSize;
	platform_io.Renderer_RenderWindow = rendererRenderWindow;
	platform_io.Renderer_SwapBuffers = rendererSwapBuffers;

	int viewid = rendererAllocViewId();
	if (viewid == -1) {
		return false;
	}
	ImGuiViewport* main_viewport = ImGui::GetMainViewport();
	RendererViewport* ud = new RendererViewport();
	ud->viewid = viewid;
	main_viewport->RendererUserData = ud;
	return true;
}

static void rendererDestroyFont() {
	ImFontAtlas* atlas = ImGui::GetIO().Fonts;
	ImTextureID texid = atlas->TexID;
	if (NULL != texid) {
		atlas->SetTexID(0);
		RendererTexture texture;
		texture.id = texid;
		BGFX(destroy_texture)(texture.s.handle);
	}
}

void rendererDestroy() {
	rendererDestroyFont();
	ImGuiViewport* viewport = ImGui::GetMainViewport();
	RendererViewport* ud = (RendererViewport*)viewport->RendererUserData;
	delete ud;
	viewport->RendererUserData = nullptr;
}

void rendererInit(lua_State* L) {
	BGFX(vertex_layout_begin)(&g_layout, BGFX_RENDERER_TYPE_NOOP);
	BGFX(vertex_layout_add)(&g_layout, BGFX_ATTRIB_POSITION, 2, BGFX_ATTRIB_TYPE_FLOAT, false, false);
	BGFX(vertex_layout_add)(&g_layout, BGFX_ATTRIB_TEXCOORD0, 2, BGFX_ATTRIB_TYPE_FLOAT, false, false);
	BGFX(vertex_layout_add)(&g_layout, BGFX_ATTRIB_COLOR0, 4, BGFX_ATTRIB_TYPE_UINT8, true, false);
	BGFX(vertex_layout_end)(&g_layout);
}

int rendererSetFontProgram(lua_State* L) {
	g_fontProgram = bgfx_program_handle_t{ BGFX_LUAHANDLE_ID(PROGRAM, (int)luaL_checkinteger(L, 1)) };
	g_fontTex = bgfx_uniform_handle_t{ BGFX_LUAHANDLE_ID(UNIFORM, (int)luaL_checkinteger(L, 2)) };
	return 0;
}

int rendererSetImageProgram(lua_State* L) {
	g_imageProgram = bgfx_program_handle_t{ BGFX_LUAHANDLE_ID(PROGRAM, (int)luaL_checkinteger(L, 1)) };
	g_imageTex = bgfx_uniform_handle_t{ BGFX_LUAHANDLE_ID(UNIFORM, (int)luaL_checkinteger(L, 2)) };
	return 0;
}

void rendererBuildFont(lua_State* L) {
	rendererDestroyFont();

	ImFontAtlas* atlas = ImGui::GetIO().Fonts;
	uint8_t* data;
	int32_t width;
	int32_t height;
	atlas->GetTexDataAsAlpha8(&data, &width, &height);

	RendererTexture texture;
	texture.s.handle = BGFX(create_texture_2d)(
		(uint16_t)width
		, (uint16_t)height
		, false
		, 1
		, BGFX_TEXTURE_FORMAT_A8
		, 0
		, BGFX(copy)(data, width * height)
		);
	texture.s.type = RendererTextureType::Font;
	atlas->SetTexID(texture.id);
	atlas->ClearInputData();
	atlas->ClearTexData();
}

ImTextureID rendererGetTextureID(lua_State* L, int lua_handle) {
	bgfx_texture_handle_t th = { BGFX_LUAHANDLE_ID(TEXTURE, lua_handle) };
	RendererTexture texture;
	texture.s.handle = th;
	texture.s.type = RendererTextureType::Image;
	return texture.id;
}
