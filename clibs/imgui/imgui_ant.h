#pragma once

#include <bgfx/c99/bgfx.h>
#include <imgui.h>
#include <lua.hpp>

namespace plat {
	struct context {
		lua_State* L;
		bgfx_view_id_t        m_viewId;
		bgfx_vertex_layout_t  m_layout;
		bgfx_program_handle_t m_fontProgram;
		bgfx_program_handle_t m_imageProgram;
		bgfx_uniform_handle_t s_fontTex;
		bgfx_uniform_handle_t s_imageTex;
	};
}
