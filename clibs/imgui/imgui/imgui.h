/*
 * Copyright 2011-2019 Branimir Karadzic. All rights reserved.
 * License: https://github.com/bkaradzic/bgfx#license-bsd-2-clause
 */

#ifndef IMGUI_H_HEADER_GUARD
#define IMGUI_H_HEADER_GUARD

#include <bgfx/c99/bgfx.h>
#include <dear-imgui/imgui.h>

#define IMGUI_MBUT_LEFT   0x01
#define IMGUI_MBUT_RIGHT  0x02
#define IMGUI_MBUT_MIDDLE 0x04
#define IMGUI_FLAGS_NONE        UINT8_C(0x00)
#define IMGUI_FLAGS_ALPHA_BLEND UINT8_C(0x01)

void imguiCreate(void* bgfx);
void imguiDestroy();
void imguiBeginFrame(int32_t _mx, int32_t _my, uint8_t _button, int32_t _scroll, uint16_t _width, uint16_t _height, int _inputChar = -1, bgfx_view_id_t _view = 255);
void imguiEndFrame();

#endif // IMGUI_H_HEADER_GUARD
