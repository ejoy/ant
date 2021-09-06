#pragma once

void* platformCreate(lua_State* L, int w, int h);
void  platformShutdown();
void  platformDestroy();
bool  platformNewFrame();
