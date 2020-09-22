#include <lua.hpp>
#include <imgui.h>

void IM_THROW(const char* err) {
    if (ImGui::GetIO().UserData) {
        lua_State* L = (lua_State*)ImGui::GetIO().UserData;
        luaL_error(L, "%s", err);
    }
}
