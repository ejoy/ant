#pragma once

struct lua_State;

namespace Rml {

bool Initialise(lua_State* L, int idx);
void Shutdown();

}
