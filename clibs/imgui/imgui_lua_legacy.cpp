#include <lua.hpp>
#include <imgui.h>
#include <imgui_internal.h>
#include <cstdint>

static int dDockBuilderGetCentralRect(lua_State * L) {
    const char* str_id = luaL_checkstring(L, 1);
    ImGuiDockNode* central_node = ImGui::DockBuilderGetCentralNode(ImGui::GetID(str_id));
    lua_pushnumber(L, central_node->Pos.x);
    lua_pushnumber(L, central_node->Pos.y);
    lua_pushnumber(L, central_node->Size.x);
    lua_pushnumber(L, central_node->Size.y);
    return 4;
}

extern "C"
int luaopen_imgui_legacy(lua_State *L) {
    lua_newtable(L);
    luaL_Reg l[] = {
        { "DockBuilderGetCentralRect", dDockBuilderGetCentralRect },
        { NULL, NULL },
    };
    luaL_setfuncs(L, l, 0);
    return 1;
}
