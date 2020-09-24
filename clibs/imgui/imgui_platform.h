#pragma once

void* platformCreate(lua_State* L, int w, int h);
void  platformDestroy();
void  platformNewFrame();
bool  platformProcessMessage();
