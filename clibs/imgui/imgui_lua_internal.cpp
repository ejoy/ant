#include <lua.hpp>
#include <imgui.h>
#include <imgui_internal.h>

static int dDockBuilderGetCentralRect(lua_State * L) {
    auto node_id = (ImGuiID)luaL_checkinteger(L, 1);
    ImGuiDockNode* central_node = ImGui::DockBuilderGetCentralNode(node_id);
    lua_pushnumber(L, central_node->Pos.x);
    lua_pushnumber(L, central_node->Pos.y);
    lua_pushnumber(L, central_node->Size.x);
    lua_pushnumber(L, central_node->Size.y);
    return 4;
}

extern "C"
int luaopen_imgui_internal(lua_State *L) {
    lua_newtable(L);
    luaL_Reg l[] = {
        { "DockBuilderGetCentralRect", dDockBuilderGetCentralRect },
        { NULL, NULL },
    };
    luaL_setfuncs(L, l, 0);
    return 1;
}
