#pragma once

void* platformCreate(lua_State* L, int w, int h);
void  platformDestroy();
bool  platformNewFrame();
