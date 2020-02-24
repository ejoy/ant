#include <lua.hpp>
#include <imgui.h>

void IM_THROW(const char* err) {
    luaL_error((lua_State*)ImGui::GetIO().UserData, "%s", err);
}
