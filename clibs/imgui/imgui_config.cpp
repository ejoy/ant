#include <lua.hpp>
#include <imgui.h>

void IM_THROW(const char* err) {
    if (ImGui::GetIO().UserData) {
        luaL_error((lua_State*)ImGui::GetIO().UserData, "%s", err);
    }
}
