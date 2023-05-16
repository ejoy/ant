#pragma once

struct lua_State;
void* platformCreate(lua_State* L, int w, int h);
void  platformShutdown();
void  platformDestroy();
bool  platformNewFrame();
void* platformGetHandle(ImGuiViewport* viewport);
