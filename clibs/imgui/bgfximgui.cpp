/*
 * Copyright 2014-2015 Daniel Collin. All rights reserved.
 * License: https://github.com/bkaradzic/bgfx#license-bsd-2-clause
 */

#include "bgfximgui.h"
#include <algorithm>
#include <glm/glm.hpp>
#include <glm/ext/matrix_clip_space.hpp>


static bgfx_interface_vtbl_t* bgfx_inf_ = 0;
#define BGFX(api) bgfx_inf_->api


/// Returns true if both internal transient index and vertex buffer have
/// enough space.
///
/// @param[in] _numVertices Number of vertices.
/// @param[in] _decl Vertex declaration.
/// @param[in] _numIndices Number of indices.
///
static bool checkAvailTransientBuffers(uint32_t _numVertices, const bgfx_vertex_decl_t& _decl, uint32_t _numIndices)
{
	return _numVertices == BGFX(get_avail_transient_vertex_buffer)(_numVertices, &_decl)
		&& (0 == _numIndices || _numIndices == BGFX(get_avail_transient_index_buffer)(_numIndices) )
		;
}

struct OcornutImguiContext
{
	void render(ImDrawData* _drawData)
	{
		const ImGuiIO& io = ImGui::GetIO();
		const float width  = io.DisplaySize.x;
		const float height = io.DisplaySize.y;

		BGFX(set_view_name)(m_viewId, "ImGui");
		BGFX(set_view_mode)(m_viewId, BGFX_VIEW_MODE_SEQUENTIAL);

		const bgfx_caps_t* caps = BGFX(get_caps)();
		{
			auto ortho = caps->homogeneousDepth
				? glm::orthoLH_NO(0.0f, width, height, 0.0f, 0.0f, 1000.0f)
				: glm::orthoLH_ZO(0.0f, width, height, 0.0f, 0.0f, 1000.0f)
				;
			BGFX(set_view_transform)(m_viewId, NULL, (const void*)&ortho[0]);
			BGFX(set_view_rect)(m_viewId, 0, 0, uint16_t(width), uint16_t(height) );
		}

		// Render command lists
		for (int32_t ii = 0, num = _drawData->CmdListsCount; ii < num; ++ii) {
			bgfx_transient_vertex_buffer_t tvb;
			bgfx_transient_index_buffer_t tib;

			const ImDrawList* drawList = _drawData->CmdLists[ii];
			uint32_t numVertices = (uint32_t)drawList->VtxBuffer.size();
			uint32_t numIndices  = (uint32_t)drawList->IdxBuffer.size();

			if (!checkAvailTransientBuffers(numVertices, m_decl, numIndices)) {
				// not enough space in transient buffer just quit drawing the rest...
				break;
			}

			BGFX(alloc_transient_vertex_buffer)(&tvb, numVertices, &m_decl);
			BGFX(alloc_transient_index_buffer)(&tib, numIndices);

			ImDrawVert* verts = (ImDrawVert*)tvb.data;
			memcpy(verts, drawList->VtxBuffer.begin(), numVertices * sizeof(ImDrawVert) );

			ImDrawIdx* indices = (ImDrawIdx*)tib.data;
			memcpy(indices, drawList->IdxBuffer.begin(), numIndices * sizeof(ImDrawIdx) );

			uint32_t offset = 0;
			for (const ImDrawCmd* cmd = drawList->CmdBuffer.begin(), *cmdEnd = drawList->CmdBuffer.end(); cmd != cmdEnd; ++cmd) {
				if (cmd->UserCallback) {
					cmd->UserCallback(drawList, cmd);
				}
				else if (0 != cmd->ElemCount) {
					uint64_t state = 0
						| BGFX_STATE_WRITE_RGB
						| BGFX_STATE_WRITE_A
						| BGFX_STATE_MSAA
						;

					assert (NULL != cmd->TextureId);
					union { ImTextureID ptr; struct { bgfx_texture_handle_t handle; uint8_t flags; uint8_t mip; } s; } texture = {cmd->TextureId };

					if (0 != (IMGUI_FLAGS_ALPHA_BLEND & texture.s.flags)) {
						state |= BGFX_STATE_BLEND_FUNC(BGFX_STATE_BLEND_SRC_ALPHA, BGFX_STATE_BLEND_INV_SRC_ALPHA);
					}

					const uint16_t xx = uint16_t(std::max(cmd->ClipRect.x, 0.0f));
					const uint16_t yy = uint16_t(std::max(cmd->ClipRect.y, 0.0f));
					BGFX(set_scissor)(xx, yy
						, uint16_t(std::min(cmd->ClipRect.z, 65535.0f)-xx)
						, uint16_t(std::min(cmd->ClipRect.w, 65535.0f)-yy)
						);

					BGFX(set_state)(state, 0);
					BGFX(set_transient_vertex_buffer)(0, &tvb, 0, numVertices);
					BGFX(set_transient_index_buffer)(&tib, offset, cmd->ElemCount);

					if (0 != texture.s.mip) {
						const float lodEnabled[4] = { float(texture.s.mip), 1.0f, 0.0f, 0.0f };
						BGFX(set_uniform)(u_imageLodEnabled, lodEnabled, 1);
						BGFX(submit)(m_viewId, m_imageProgram, 0, false);
					}
					else {
						BGFX(set_texture)(0, s_tex, texture.s.handle, UINT32_MAX);
						BGFX(submit)(m_viewId, m_program, 0, false);
					}
				}

				offset += cmd->ElemCount;
			}
		}
	}

	void create(bgfx_view_id_t _viewId,
		bgfx_program_handle_t _normalProgram,
		bgfx_program_handle_t _imageProgram,
		bgfx_uniform_handle_t _tex,
		bgfx_uniform_handle_t _imageLodEnabled
	)
	{
		m_viewId = _viewId;
		m_imgui = ImGui::CreateContext();

		m_program = _normalProgram;
		m_imageProgram = _imageProgram;
		u_imageLodEnabled = _imageLodEnabled;
		s_tex = _tex;

		BGFX(vertex_decl_begin)(&m_decl, BGFX_RENDERER_TYPE_NOOP);
		BGFX(vertex_decl_add)(&m_decl, BGFX_ATTRIB_POSITION,  2, BGFX_ATTRIB_TYPE_FLOAT, false, false);
		BGFX(vertex_decl_add)(&m_decl, BGFX_ATTRIB_TEXCOORD0, 2, BGFX_ATTRIB_TYPE_FLOAT, false, false);
		BGFX(vertex_decl_add)(&m_decl, BGFX_ATTRIB_COLOR0,    4, BGFX_ATTRIB_TYPE_UINT8,  true, false);
		BGFX(vertex_decl_end)(&m_decl);
	}

	void destroy()
	{
		ImGui::DestroyContext(m_imgui);
		BGFX(destroy_uniform)(s_tex);
		BGFX(destroy_uniform)(u_imageLodEnabled);
		BGFX(destroy_program)(m_imageProgram);
		BGFX(destroy_program)(m_program);
	}

	ImGuiContext*         m_imgui;
	bgfx_vertex_decl_t    m_decl;
	bgfx_program_handle_t m_program;
	bgfx_program_handle_t m_imageProgram;
	bgfx_uniform_handle_t s_tex;
	bgfx_uniform_handle_t u_imageLodEnabled;
	bgfx_view_id_t m_viewId;
};

static OcornutImguiContext s_ctx;

void imguiCreate(void* bgfx,
	bgfx_view_id_t _viewId,
	bgfx_program_handle_t _normalProgram,
	bgfx_program_handle_t _imageProgram,
	bgfx_uniform_handle_t _tex,
	bgfx_uniform_handle_t _imageLodEnabled
)
{
	bgfx_inf_ = (bgfx_interface_vtbl_t*)bgfx;
	s_ctx.create(_viewId, _normalProgram, _imageProgram, _tex, _imageLodEnabled);
}

void imguiDestroy()
{
	s_ctx.destroy();
}

void imguiRender(ImDrawData* _drawData)
{
	s_ctx.render(_drawData);
}

#define STB_RECT_PACK_IMPLEMENTATION
#include <imstb_rectpack.h>
#define STB_TRUETYPE_IMPLEMENTATION
#include <imstb_truetype.h>
