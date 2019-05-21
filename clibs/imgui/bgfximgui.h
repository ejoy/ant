/*
 * Copyright 2011-2019 Branimir Karadzic. All rights reserved.
 * License: https://github.com/bkaradzic/bgfx#license-bsd-2-clause
 */

#ifndef IMGUI_H_HEADER_GUARD
#define IMGUI_H_HEADER_GUARD

#include <bgfx/c99/bgfx.h>
#include <imgui.h>

#define IMGUI_FLAGS_NONE        UINT8_C(0x00)
#define IMGUI_FLAGS_ALPHA_BLEND UINT8_C(0x01)

void imguiCreate(void* bgfx,
	bgfx_view_id_t _viewId,
	bgfx_program_handle_t _normalProgram,
	bgfx_program_handle_t _imageProgram,
	bgfx_uniform_handle_t _tex,
	bgfx_uniform_handle_t _imageLodEnabled
);
void imguiDestroy();
void imguiRender(ImDrawData* _drawData);

#endif // IMGUI_H_HEADER_GUARD
