#include <lua.hpp>
#include <imgui.h>
#include "imgui_ant.h"

void IM_THROW(const char* err) {
    if (ImGui::GetIO().UserData) {
        plat::context* ctx = (plat::context*)ImGui::GetIO().UserData;
        luaL_error(ctx->L, "%s", err);
    }
}
