#pragma once

#include <ImGui.h>
#include <lua.hpp>

void rendererInit(lua_State* L);
bool rendererCreate();
void rendererDestroy();
void rendererDrawData(ImGuiViewport* viewport);
int  rendererSetFontProgram(lua_State* L);
int  rendererSetImageProgram(lua_State* L);
void rendererBuildFont(lua_State* L);
ImTextureID rendererGetTextureID(lua_State* L, int lua_handle);
