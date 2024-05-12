#include <imgui.h>
#include <lua.hpp>
#include <algorithm>
#include <glm/glm.hpp>
#include <glm/ext/matrix_clip_space.hpp>
#include <cstring>
#include <cstdlib>
#include <stdlib.h>
#include "bgfx_interface.h"
#include "luabgfx.h"
#include "imgui_impl_platform.h"
#include "imgui_impl_bgfx.h"

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

struct RendererContext {
	bgfx_vertex_layout_t layout;
	bgfx_program_handle_t fontProgram;
	bgfx_program_handle_t imageProgram;
	bgfx_uniform_handle_t fontTex;
	bgfx_uniform_handle_t imageTex;
	std::vector<int> viewIdPool;
};
static RendererContext g_ctx;

static BGFX_HANDLE bgfxGetHandleType(int id) {
	return (BGFX_HANDLE)((id >> 16) & 0x0f);
}

static uint16_t bgfxGetHandle(int id) {
	return (uint16_t)(id & 0xffff);
}

void ImGui_ImplBgfx_RenderDrawData(ImGuiViewport* viewport) {
	RendererViewport* ud = (RendererViewport*)viewport->RendererUserData;
	const ImDrawData* drawData = viewport->DrawData;
	const ImVec2& clip_size = drawData->DisplaySize;
	const ImVec2 clip_offset = drawData->DisplayPos;
	const ImVec2& clip_scale = drawData->FramebufferScale;

	bgfx_encoder_t* encoder = BGFX(encoder_begin)(false);
	BGFX(set_view_name)(ud->viewid, "ImGui", 6);
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

		if (numVertices != BGFX(get_avail_transient_vertex_buffer)(numVertices, &g_ctx.layout)
			|| numIndices != BGFX(get_avail_transient_index_buffer)(numIndices, false)) {
			break;
		}

		bgfx_transient_vertex_buffer_t tvb;
		bgfx_transient_index_buffer_t tib;
		BGFX(alloc_transient_vertex_buffer)(&tvb, numVertices, &g_ctx.layout);
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
				BGFX(encoder_set_texture)(encoder, 0, g_ctx.fontTex, texture.s.handle, UINT32_MAX);
				BGFX(encoder_submit)(encoder, ud->viewid, g_ctx.fontProgram, 0, BGFX_DISCARD_STATE);
			}
			else {
				BGFX(encoder_set_texture)(encoder, 0, g_ctx.imageTex, texture.s.handle, UINT32_MAX);
				BGFX(encoder_submit)(encoder, ud->viewid, g_ctx.imageProgram, 0, BGFX_DISCARD_STATE);
			}
		}
	}
	BGFX(encoder_discard)(encoder, BGFX_DISCARD_ALL);
	BGFX(encoder_end)(encoder);
}

static void ImGui_ImplBgfx_FreeViewId(int viewid) {
	g_ctx.viewIdPool.push_back(viewid);
}

static int ImGui_ImplBgfx_AllocViewId() {
	if (g_ctx.viewIdPool.empty()) {
		return -1;
	}
	int viewid = g_ctx.viewIdPool.back();
	g_ctx.viewIdPool.pop_back();
	return viewid;
}

static void ImGui_ImplBgfx_CreateWindow(ImGuiViewport* viewport) {
	int viewid = ImGui_ImplBgfx_AllocViewId();
	if (viewid == -1) {
		return;
	}
	bgfx_frame_buffer_handle_t fb = BGFX(create_frame_buffer_from_nwh)(
		viewport->PlatformHandleRaw,
		(uint16_t)viewport->Size.x,
		(uint16_t)viewport->Size.y,
		BGFX_TEXTURE_FORMAT_RGBA8,
		BGFX_TEXTURE_FORMAT_D24S8
		);
	if (!BGFX_HANDLE_IS_VALID(fb)) {
		ImGui_ImplBgfx_FreeViewId(viewid);
		return;
	}
	RendererViewport* ud = new RendererViewport;
	viewport->RendererUserData = ud;
	ud->viewid = viewid;
	ud->fb = fb;
	BGFX(set_view_frame_buffer)(ud->viewid, fb);
}

static void ImGui_ImplBgfx_DestroyWindow(ImGuiViewport* viewport) {
	RendererViewport* ud = (RendererViewport*)viewport->RendererUserData;
	if (ud) {
		if (BGFX_HANDLE_IS_VALID(ud->fb)) {
			BGFX(destroy_frame_buffer)(ud->fb);
		}
		if (ud->viewid != -1) {
			ImGui_ImplBgfx_FreeViewId(ud->viewid);
		}
		delete ud;
		viewport->RendererUserData = nullptr;
	}
}

static void ImGui_ImplBgfx_SetWindowSize(ImGuiViewport* viewport, ImVec2 size) {
	RendererViewport* ud = (RendererViewport*)viewport->RendererUserData;
	bgfx_frame_buffer_handle_t fb = BGFX(create_frame_buffer_from_nwh)(
		viewport->PlatformHandleRaw,
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

static void ImGui_ImplBgfx_RenderWindow(ImGuiViewport* viewport, void*) {
	ImGui_ImplBgfx_RenderDrawData(viewport);
}

static void ImGui_ImplBgfx_SwapBuffers(ImGuiViewport* viewport, void*) {
}

bool ImGui_ImplBgfx_Init(RendererInitArgs& args) {
	if (0
		|| bgfxGetHandleType(args.fontProg) != BGFX_HANDLE_PROGRAM
		|| bgfxGetHandleType(args.imageProg) != BGFX_HANDLE_PROGRAM
		|| bgfxGetHandleType(args.fontUniform) != BGFX_HANDLE_UNIFORM
		|| bgfxGetHandleType(args.imageUniform) != BGFX_HANDLE_UNIFORM
	) {
		return false;
	}
	g_ctx.fontProgram = bgfx_program_handle_t { bgfxGetHandle(args.fontProg) };
	g_ctx.imageProgram = bgfx_program_handle_t { bgfxGetHandle(args.imageProg) };
	g_ctx.fontTex = bgfx_uniform_handle_t { bgfxGetHandle(args.fontUniform) };
	g_ctx.imageTex = bgfx_uniform_handle_t { bgfxGetHandle(args.imageUniform) };
	BGFX(vertex_layout_begin)(&g_ctx.layout, BGFX_RENDERER_TYPE_NOOP);
	BGFX(vertex_layout_add)(&g_ctx.layout, BGFX_ATTRIB_POSITION, 2, BGFX_ATTRIB_TYPE_FLOAT, false, false);
	BGFX(vertex_layout_add)(&g_ctx.layout, BGFX_ATTRIB_TEXCOORD0, 2, BGFX_ATTRIB_TYPE_FLOAT, false, false);
	BGFX(vertex_layout_add)(&g_ctx.layout, BGFX_ATTRIB_COLOR0, 4, BGFX_ATTRIB_TYPE_UINT8, true, false);
	BGFX(vertex_layout_end)(&g_ctx.layout);
	g_ctx.viewIdPool = std::move(args.viewIdPool);

	ImGuiIO& io = ImGui::GetIO();
	io.BackendFlags |= ImGuiBackendFlags_RendererHasViewports;

	ImGuiPlatformIO& platform_io = ImGui::GetPlatformIO();
	platform_io.Renderer_CreateWindow = ImGui_ImplBgfx_CreateWindow;
	platform_io.Renderer_DestroyWindow = ImGui_ImplBgfx_DestroyWindow;
	platform_io.Renderer_SetWindowSize = ImGui_ImplBgfx_SetWindowSize;
	platform_io.Renderer_RenderWindow = ImGui_ImplBgfx_RenderWindow;
	platform_io.Renderer_SwapBuffers = ImGui_ImplBgfx_SwapBuffers;

	int viewid = ImGui_ImplBgfx_AllocViewId();
	if (viewid == -1) {
		return false;
	}
	ImGuiViewport* main_viewport = ImGui::GetMainViewport();
	RendererViewport* ud = new RendererViewport();
	ud->viewid = viewid;
	main_viewport->RendererUserData = ud;
	return true;
}

static void ImGui_ImplBgfx_DestroyFontsTexture() {
	ImFontAtlas* atlas = ImGui::GetIO().Fonts;
	ImTextureID texid = atlas->TexID;
	if (NULL != texid) {
		atlas->SetTexID(0);
		RendererTexture texture;
		texture.id = texid;
		BGFX(destroy_texture)(texture.s.handle);
	}
}

void ImGui_ImplBgfx_Shutdown() {
	ImGui_ImplBgfx_DestroyFontsTexture();
	ImGui::DestroyPlatformWindows();
	ImGuiViewport* viewport = ImGui::GetMainViewport();
	RendererViewport* ud = (RendererViewport*)viewport->RendererUserData;
	delete ud;
	viewport->RendererUserData = nullptr;
}

void ImGui_ImplBgfx_CreateFontsTexture() {
	ImGui_ImplBgfx_DestroyFontsTexture();

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

std::optional<ImTextureID> ImGui_ImplBgfx_GetTextureID(int tex) {
	if (bgfxGetHandleType(tex) != BGFX_HANDLE_TEXTURE) {
		return std::nullopt;
	}
	bgfx_texture_handle_t th = { bgfxGetHandle(tex) };
	RendererTexture texture;
	texture.s.handle = th;
	texture.s.type = RendererTextureType::Image;
	return texture.id;
}
