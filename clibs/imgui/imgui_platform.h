#pragma once

bool platformCreate(lua_State* L, int w, int h);
void platformDestroy();
void platformNewFrame();
void platformMainLoop(lua_State* L);
