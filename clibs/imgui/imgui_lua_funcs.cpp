//
// Automatically generated file; DO NOT EDIT.
//
#include <imgui.h>
#include <lua.hpp>

namespace imgui_lua {

lua_CFunction str_format = NULL;

static void find_str_format(lua_State* L) {
    luaopen_string(L);
    lua_getfield(L, -1, "format");
    str_format = lua_tocfunction(L, -1);
    lua_pop(L, 2);
}

static lua_Number field_tonumber(lua_State* L, int idx, lua_Integer i) {
    lua_geti(L, idx, i);
    lua_Number v = luaL_checknumber(L, -1);
    lua_pop(L, 1);
    return v;
}

static int ColorEdit3(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _col_index = 2;
    float col[3] = {
        (float)field_tonumber(L, 2, 1),
        (float)field_tonumber(L, 2, 2),
        (float)field_tonumber(L, 2, 3),
    };
    auto flags = (ImGuiColorEditFlags)luaL_optinteger(L, 7, lua_Integer(ImGuiColorEditFlags_None));
    auto _retval = ImGui::ColorEdit3(label, col, flags);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushnumber(L, col[1]);
        lua_seti(L, _col_index, 1);
        lua_pushnumber(L, col[2]);
        lua_seti(L, _col_index, 2);
        lua_pushnumber(L, col[3]);
        lua_seti(L, _col_index, 3);
    };
    return 1;
}

static int ColorEdit4(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _col_index = 2;
    float col[4] = {
        (float)field_tonumber(L, 2, 1),
        (float)field_tonumber(L, 2, 2),
        (float)field_tonumber(L, 2, 3),
        (float)field_tonumber(L, 2, 4),
    };
    auto flags = (ImGuiColorEditFlags)luaL_optinteger(L, 7, lua_Integer(ImGuiColorEditFlags_None));
    auto _retval = ImGui::ColorEdit4(label, col, flags);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushnumber(L, col[1]);
        lua_seti(L, _col_index, 1);
        lua_pushnumber(L, col[2]);
        lua_seti(L, _col_index, 2);
        lua_pushnumber(L, col[3]);
        lua_seti(L, _col_index, 3);
        lua_pushnumber(L, col[4]);
        lua_seti(L, _col_index, 4);
    };
    return 1;
}

static int ColorPicker3(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _col_index = 2;
    float col[3] = {
        (float)field_tonumber(L, 2, 1),
        (float)field_tonumber(L, 2, 2),
        (float)field_tonumber(L, 2, 3),
    };
    auto flags = (ImGuiColorEditFlags)luaL_optinteger(L, 7, lua_Integer(ImGuiColorEditFlags_None));
    auto _retval = ImGui::ColorPicker3(label, col, flags);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushnumber(L, col[1]);
        lua_seti(L, _col_index, 1);
        lua_pushnumber(L, col[2]);
        lua_seti(L, _col_index, 2);
        lua_pushnumber(L, col[3]);
        lua_seti(L, _col_index, 3);
    };
    return 1;
}

static int ColorButton(lua_State* L) {
    auto desc_id = luaL_checkstring(L, 1);
    auto col = ImVec4 {
        (float)luaL_checknumber(L, 2),
        (float)luaL_checknumber(L, 3),
        (float)luaL_checknumber(L, 4),
        (float)luaL_checknumber(L, 5),
    };
    auto flags = (ImGuiColorEditFlags)luaL_optinteger(L, 6, lua_Integer(ImGuiColorEditFlags_None));
    auto _retval = ImGui::ColorButton(desc_id, col, flags);
    lua_pushboolean(L, _retval);
    return 1;
}

static int ColorButtonEx(lua_State* L) {
    auto desc_id = luaL_checkstring(L, 1);
    auto col = ImVec4 {
        (float)luaL_checknumber(L, 2),
        (float)luaL_checknumber(L, 3),
        (float)luaL_checknumber(L, 4),
        (float)luaL_checknumber(L, 5),
    };
    auto flags = (ImGuiColorEditFlags)luaL_optinteger(L, 6, lua_Integer(ImGuiColorEditFlags_None));
    auto size = ImVec2 {
        (float)luaL_optnumber(L, 7, 0.f),
        (float)luaL_optnumber(L, 8, 0.f),
    };
    auto _retval = ImGui::ColorButton(desc_id, col, flags, size);
    lua_pushboolean(L, _retval);
    return 1;
}

static int SetColorEditOptions(lua_State* L) {
    auto flags = (ImGuiColorEditFlags)luaL_checkinteger(L, 1);
    ImGui::SetColorEditOptions(flags);
    return 0;
}

static int TreeNode(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    auto _retval = ImGui::TreeNode(label);
    lua_pushboolean(L, _retval);
    return 1;
}

static int TreeNodeStr(lua_State* L) {
    auto str_id = luaL_checkstring(L, 1);
    lua_pushcfunction(L, str_format);
    lua_insert(L, 2);
    lua_call(L, lua_gettop(L) - 2, 1);
    const char* _fmtstr = lua_tostring(L, -1);
    auto _retval = ImGui::TreeNode(str_id, "%s", _fmtstr);
    lua_pushboolean(L, _retval);
    return 1;
}

static int TreeNodePtr(lua_State* L) {
    auto ptr_id = lua_touserdata(L, 1);
    lua_pushcfunction(L, str_format);
    lua_insert(L, 2);
    lua_call(L, lua_gettop(L) - 2, 1);
    const char* _fmtstr = lua_tostring(L, -1);
    auto _retval = ImGui::TreeNode(ptr_id, "%s", _fmtstr);
    lua_pushboolean(L, _retval);
    return 1;
}

static int TreeNodeEx(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    auto flags = (ImGuiTreeNodeFlags)luaL_optinteger(L, 2, lua_Integer(ImGuiTreeNodeFlags_None));
    auto _retval = ImGui::TreeNodeEx(label, flags);
    lua_pushboolean(L, _retval);
    return 1;
}

static int TreeNodeExStr(lua_State* L) {
    auto str_id = luaL_checkstring(L, 1);
    auto flags = (ImGuiTreeNodeFlags)luaL_checkinteger(L, 2);
    lua_pushcfunction(L, str_format);
    lua_insert(L, 3);
    lua_call(L, lua_gettop(L) - 3, 1);
    const char* _fmtstr = lua_tostring(L, -1);
    auto _retval = ImGui::TreeNodeEx(str_id, flags, "%s", _fmtstr);
    lua_pushboolean(L, _retval);
    return 1;
}

static int TreeNodeExPtr(lua_State* L) {
    auto ptr_id = lua_touserdata(L, 1);
    auto flags = (ImGuiTreeNodeFlags)luaL_checkinteger(L, 2);
    lua_pushcfunction(L, str_format);
    lua_insert(L, 3);
    lua_call(L, lua_gettop(L) - 3, 1);
    const char* _fmtstr = lua_tostring(L, -1);
    auto _retval = ImGui::TreeNodeEx(ptr_id, flags, "%s", _fmtstr);
    lua_pushboolean(L, _retval);
    return 1;
}

static int TreePush(lua_State* L) {
    auto str_id = luaL_checkstring(L, 1);
    ImGui::TreePush(str_id);
    return 0;
}

static int TreePushPtr(lua_State* L) {
    auto ptr_id = lua_touserdata(L, 1);
    ImGui::TreePush(ptr_id);
    return 0;
}

static int TreePop(lua_State* L) {
    ImGui::TreePop();
    return 0;
}

static int GetTreeNodeToLabelSpacing(lua_State* L) {
    auto _retval = ImGui::GetTreeNodeToLabelSpacing();
    lua_pushnumber(L, _retval);
    return 1;
}

static int CollapsingHeader(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    auto flags = (ImGuiTreeNodeFlags)luaL_optinteger(L, 2, lua_Integer(ImGuiTreeNodeFlags_None));
    auto _retval = ImGui::CollapsingHeader(label, flags);
    lua_pushboolean(L, _retval);
    return 1;
}

static int CollapsingHeaderBoolPtr(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    bool has_p_visible = !lua_isnil(L, 2);
    bool p_visible = true;
    auto flags = (ImGuiTreeNodeFlags)luaL_optinteger(L, 3, lua_Integer(ImGuiTreeNodeFlags_None));
    auto _retval = ImGui::CollapsingHeader(label, (has_p_visible? &p_visible: NULL), flags);
    lua_pushboolean(L, _retval);
    lua_pushboolean(L, has_p_visible || p_visible);
    return 2;
}

static int SetNextItemOpen(lua_State* L) {
    auto is_open = !!lua_toboolean(L, 1);
    auto cond = (ImGuiCond)luaL_optinteger(L, 2, lua_Integer(ImGuiCond_None));
    ImGui::SetNextItemOpen(is_open, cond);
    return 0;
}

static int Selectable(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    auto _retval = ImGui::Selectable(label);
    lua_pushboolean(L, _retval);
    return 1;
}

static int SelectableEx(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    auto selected = lua_isnoneornil(L, 2)? false: !!lua_toboolean(L, 2);
    auto flags = (ImGuiSelectableFlags)luaL_optinteger(L, 3, lua_Integer(ImGuiSelectableFlags_None));
    auto size = ImVec2 {
        (float)luaL_optnumber(L, 4, 0.f),
        (float)luaL_optnumber(L, 5, 0.f),
    };
    auto _retval = ImGui::Selectable(label, selected, flags, size);
    lua_pushboolean(L, _retval);
    return 1;
}

static int SelectableBoolPtr(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    bool has_p_selected = !lua_isnil(L, 2);
    bool p_selected = true;
    auto flags = (ImGuiSelectableFlags)luaL_optinteger(L, 3, lua_Integer(ImGuiSelectableFlags_None));
    auto _retval = ImGui::Selectable(label, (has_p_selected? &p_selected: NULL), flags);
    lua_pushboolean(L, _retval);
    lua_pushboolean(L, has_p_selected || p_selected);
    return 2;
}

static int SelectableBoolPtrEx(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    bool has_p_selected = !lua_isnil(L, 2);
    bool p_selected = true;
    auto flags = (ImGuiSelectableFlags)luaL_optinteger(L, 3, lua_Integer(ImGuiSelectableFlags_None));
    auto size = ImVec2 {
        (float)luaL_optnumber(L, 4, 0.f),
        (float)luaL_optnumber(L, 5, 0.f),
    };
    auto _retval = ImGui::Selectable(label, (has_p_selected? &p_selected: NULL), flags, size);
    lua_pushboolean(L, _retval);
    lua_pushboolean(L, has_p_selected || p_selected);
    return 2;
}

static int BeginListBox(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    auto size = ImVec2 {
        (float)luaL_optnumber(L, 2, 0.f),
        (float)luaL_optnumber(L, 3, 0.f),
    };
    auto _retval = ImGui::BeginListBox(label, size);
    lua_pushboolean(L, _retval);
    return 1;
}

static int EndListBox(lua_State* L) {
    ImGui::EndListBox();
    return 0;
}

static int BeginMenuBar(lua_State* L) {
    auto _retval = ImGui::BeginMenuBar();
    lua_pushboolean(L, _retval);
    return 1;
}

static int EndMenuBar(lua_State* L) {
    ImGui::EndMenuBar();
    return 0;
}

static int BeginMainMenuBar(lua_State* L) {
    auto _retval = ImGui::BeginMainMenuBar();
    lua_pushboolean(L, _retval);
    return 1;
}

static int EndMainMenuBar(lua_State* L) {
    ImGui::EndMainMenuBar();
    return 0;
}

static int BeginMenu(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    auto _retval = ImGui::BeginMenu(label);
    lua_pushboolean(L, _retval);
    return 1;
}

static int BeginMenuEx(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    auto enabled = lua_isnoneornil(L, 2)? true: !!lua_toboolean(L, 2);
    auto _retval = ImGui::BeginMenu(label, enabled);
    lua_pushboolean(L, _retval);
    return 1;
}

static int EndMenu(lua_State* L) {
    ImGui::EndMenu();
    return 0;
}

static int MenuItem(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    auto _retval = ImGui::MenuItem(label);
    lua_pushboolean(L, _retval);
    return 1;
}

static int MenuItemEx(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    auto shortcut = luaL_optstring(L, 2, NULL);
    auto selected = lua_isnoneornil(L, 3)? false: !!lua_toboolean(L, 3);
    auto enabled = lua_isnoneornil(L, 4)? true: !!lua_toboolean(L, 4);
    auto _retval = ImGui::MenuItem(label, shortcut, selected, enabled);
    lua_pushboolean(L, _retval);
    return 1;
}

static int MenuItemBoolPtr(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    auto shortcut = luaL_checkstring(L, 2);
    bool has_p_selected = !lua_isnil(L, 3);
    bool p_selected = true;
    auto enabled = lua_isnoneornil(L, 4)? true: !!lua_toboolean(L, 4);
    auto _retval = ImGui::MenuItem(label, shortcut, (has_p_selected? &p_selected: NULL), enabled);
    lua_pushboolean(L, _retval);
    lua_pushboolean(L, has_p_selected || p_selected);
    return 2;
}

static int BeginTooltip(lua_State* L) {
    auto _retval = ImGui::BeginTooltip();
    lua_pushboolean(L, _retval);
    return 1;
}

static int EndTooltip(lua_State* L) {
    ImGui::EndTooltip();
    return 0;
}

static int SetTooltip(lua_State* L) {
    lua_pushcfunction(L, str_format);
    lua_insert(L, 1);
    lua_call(L, lua_gettop(L) - 1, 1);
    const char* _fmtstr = lua_tostring(L, -1);
    ImGui::SetTooltip("%s", _fmtstr);
    return 0;
}

static int BeginItemTooltip(lua_State* L) {
    auto _retval = ImGui::BeginItemTooltip();
    lua_pushboolean(L, _retval);
    return 1;
}

static int SetItemTooltip(lua_State* L) {
    lua_pushcfunction(L, str_format);
    lua_insert(L, 1);
    lua_call(L, lua_gettop(L) - 1, 1);
    const char* _fmtstr = lua_tostring(L, -1);
    ImGui::SetItemTooltip("%s", _fmtstr);
    return 0;
}

static int BeginPopup(lua_State* L) {
    auto str_id = luaL_checkstring(L, 1);
    auto flags = (ImGuiWindowFlags)luaL_optinteger(L, 2, lua_Integer(ImGuiWindowFlags_None));
    auto _retval = ImGui::BeginPopup(str_id, flags);
    lua_pushboolean(L, _retval);
    return 1;
}

static int BeginPopupModal(lua_State* L) {
    auto name = luaL_checkstring(L, 1);
    bool has_p_open = !lua_isnil(L, 2);
    bool p_open = true;
    auto flags = (ImGuiWindowFlags)luaL_optinteger(L, 3, lua_Integer(ImGuiWindowFlags_None));
    auto _retval = ImGui::BeginPopupModal(name, (has_p_open? &p_open: NULL), flags);
    lua_pushboolean(L, _retval);
    lua_pushboolean(L, has_p_open || p_open);
    return 2;
}

static int EndPopup(lua_State* L) {
    ImGui::EndPopup();
    return 0;
}

static int OpenPopup(lua_State* L) {
    auto str_id = luaL_checkstring(L, 1);
    auto popup_flags = (ImGuiPopupFlags)luaL_optinteger(L, 2, lua_Integer(ImGuiPopupFlags_None));
    ImGui::OpenPopup(str_id, popup_flags);
    return 0;
}

static int OpenPopupID(lua_State* L) {
    auto id = (ImGuiID)luaL_checkinteger(L, 1);
    auto popup_flags = (ImGuiPopupFlags)luaL_optinteger(L, 2, lua_Integer(ImGuiPopupFlags_None));
    ImGui::OpenPopup(id, popup_flags);
    return 0;
}

static int OpenPopupOnItemClick(lua_State* L) {
    auto str_id = luaL_optstring(L, 1, NULL);
    auto popup_flags = (ImGuiPopupFlags)luaL_optinteger(L, 2, lua_Integer(ImGuiPopupFlags_MouseButtonRight));
    ImGui::OpenPopupOnItemClick(str_id, popup_flags);
    return 0;
}

static int CloseCurrentPopup(lua_State* L) {
    ImGui::CloseCurrentPopup();
    return 0;
}

static int BeginPopupContextItem(lua_State* L) {
    auto _retval = ImGui::BeginPopupContextItem();
    lua_pushboolean(L, _retval);
    return 1;
}

static int BeginPopupContextItemEx(lua_State* L) {
    auto str_id = luaL_optstring(L, 1, NULL);
    auto popup_flags = (ImGuiPopupFlags)luaL_optinteger(L, 2, lua_Integer(ImGuiPopupFlags_MouseButtonRight));
    auto _retval = ImGui::BeginPopupContextItem(str_id, popup_flags);
    lua_pushboolean(L, _retval);
    return 1;
}

static int BeginPopupContextWindow(lua_State* L) {
    auto _retval = ImGui::BeginPopupContextWindow();
    lua_pushboolean(L, _retval);
    return 1;
}

static int BeginPopupContextWindowEx(lua_State* L) {
    auto str_id = luaL_optstring(L, 1, NULL);
    auto popup_flags = (ImGuiPopupFlags)luaL_optinteger(L, 2, lua_Integer(ImGuiPopupFlags_MouseButtonRight));
    auto _retval = ImGui::BeginPopupContextWindow(str_id, popup_flags);
    lua_pushboolean(L, _retval);
    return 1;
}

static int BeginPopupContextVoid(lua_State* L) {
    auto _retval = ImGui::BeginPopupContextVoid();
    lua_pushboolean(L, _retval);
    return 1;
}

static int BeginPopupContextVoidEx(lua_State* L) {
    auto str_id = luaL_optstring(L, 1, NULL);
    auto popup_flags = (ImGuiPopupFlags)luaL_optinteger(L, 2, lua_Integer(ImGuiPopupFlags_MouseButtonRight));
    auto _retval = ImGui::BeginPopupContextVoid(str_id, popup_flags);
    lua_pushboolean(L, _retval);
    return 1;
}

static int IsPopupOpen(lua_State* L) {
    auto str_id = luaL_checkstring(L, 1);
    auto flags = (ImGuiPopupFlags)luaL_optinteger(L, 2, lua_Integer(ImGuiPopupFlags_None));
    auto _retval = ImGui::IsPopupOpen(str_id, flags);
    lua_pushboolean(L, _retval);
    return 1;
}

static int BeginTable(lua_State* L) {
    auto str_id = luaL_checkstring(L, 1);
    auto column = (int)luaL_checkinteger(L, 2);
    auto flags = (ImGuiTableFlags)luaL_optinteger(L, 3, lua_Integer(ImGuiTableFlags_None));
    auto _retval = ImGui::BeginTable(str_id, column, flags);
    lua_pushboolean(L, _retval);
    return 1;
}

static int BeginTableEx(lua_State* L) {
    auto str_id = luaL_checkstring(L, 1);
    auto column = (int)luaL_checkinteger(L, 2);
    auto flags = (ImGuiTableFlags)luaL_optinteger(L, 3, lua_Integer(ImGuiTableFlags_None));
    auto outer_size = ImVec2 {
        (float)luaL_optnumber(L, 4, 0.f),
        (float)luaL_optnumber(L, 5, 0.f),
    };
    auto inner_width = (float)luaL_optnumber(L, 6, 0.0f);
    auto _retval = ImGui::BeginTable(str_id, column, flags, outer_size, inner_width);
    lua_pushboolean(L, _retval);
    return 1;
}

static int EndTable(lua_State* L) {
    ImGui::EndTable();
    return 0;
}

static int TableNextRow(lua_State* L) {
    ImGui::TableNextRow();
    return 0;
}

static int TableNextRowEx(lua_State* L) {
    auto row_flags = (ImGuiTableRowFlags)luaL_optinteger(L, 1, lua_Integer(ImGuiTableRowFlags_None));
    auto min_row_height = (float)luaL_optnumber(L, 2, 0.0f);
    ImGui::TableNextRow(row_flags, min_row_height);
    return 0;
}

static int TableNextColumn(lua_State* L) {
    auto _retval = ImGui::TableNextColumn();
    lua_pushboolean(L, _retval);
    return 1;
}

static int TableSetColumnIndex(lua_State* L) {
    auto column_n = (int)luaL_checkinteger(L, 1);
    auto _retval = ImGui::TableSetColumnIndex(column_n);
    lua_pushboolean(L, _retval);
    return 1;
}

static int TableSetupColumn(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    auto flags = (ImGuiTableColumnFlags)luaL_optinteger(L, 2, lua_Integer(ImGuiTableColumnFlags_None));
    ImGui::TableSetupColumn(label, flags);
    return 0;
}

static int TableSetupColumnEx(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    auto flags = (ImGuiTableColumnFlags)luaL_optinteger(L, 2, lua_Integer(ImGuiTableColumnFlags_None));
    auto init_width_or_weight = (float)luaL_optnumber(L, 3, 0.0f);
    auto user_id = (ImGuiID)luaL_optinteger(L, 4, 0);
    ImGui::TableSetupColumn(label, flags, init_width_or_weight, user_id);
    return 0;
}

static int TableSetupScrollFreeze(lua_State* L) {
    auto cols = (int)luaL_checkinteger(L, 1);
    auto rows = (int)luaL_checkinteger(L, 2);
    ImGui::TableSetupScrollFreeze(cols, rows);
    return 0;
}

static int TableHeader(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    ImGui::TableHeader(label);
    return 0;
}

static int TableHeadersRow(lua_State* L) {
    ImGui::TableHeadersRow();
    return 0;
}

static int TableAngledHeadersRow(lua_State* L) {
    ImGui::TableAngledHeadersRow();
    return 0;
}

static int TableGetColumnCount(lua_State* L) {
    auto _retval = ImGui::TableGetColumnCount();
    lua_pushinteger(L, _retval);
    return 1;
}

static int TableGetColumnIndex(lua_State* L) {
    auto _retval = ImGui::TableGetColumnIndex();
    lua_pushinteger(L, _retval);
    return 1;
}

static int TableGetRowIndex(lua_State* L) {
    auto _retval = ImGui::TableGetRowIndex();
    lua_pushinteger(L, _retval);
    return 1;
}

static int TableGetColumnName(lua_State* L) {
    auto column_n = (int)luaL_optinteger(L, 1, -1);
    auto _retval = ImGui::TableGetColumnName(column_n);
    lua_pushstring(L, _retval);
    return 1;
}

static int TableGetColumnFlags(lua_State* L) {
    auto column_n = (int)luaL_optinteger(L, 1, -1);
    auto _retval = ImGui::TableGetColumnFlags(column_n);
    lua_pushinteger(L, _retval);
    return 1;
}

static int TableSetColumnEnabled(lua_State* L) {
    auto column_n = (int)luaL_checkinteger(L, 1);
    auto v = !!lua_toboolean(L, 2);
    ImGui::TableSetColumnEnabled(column_n, v);
    return 0;
}

static int TableSetBgColor(lua_State* L) {
    auto target = (ImGuiTableBgTarget)luaL_checkinteger(L, 1);
    auto color = (ImU32)luaL_checkinteger(L, 2);
    auto column_n = (int)luaL_optinteger(L, 3, -1);
    ImGui::TableSetBgColor(target, color, column_n);
    return 0;
}

static int BeginTabBar(lua_State* L) {
    auto str_id = luaL_checkstring(L, 1);
    auto flags = (ImGuiTabBarFlags)luaL_optinteger(L, 2, lua_Integer(ImGuiTabBarFlags_None));
    auto _retval = ImGui::BeginTabBar(str_id, flags);
    lua_pushboolean(L, _retval);
    return 1;
}

static int EndTabBar(lua_State* L) {
    ImGui::EndTabBar();
    return 0;
}

static int BeginTabItem(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    bool has_p_open = !lua_isnil(L, 2);
    bool p_open = true;
    auto flags = (ImGuiTabItemFlags)luaL_optinteger(L, 3, lua_Integer(ImGuiTabItemFlags_None));
    auto _retval = ImGui::BeginTabItem(label, (has_p_open? &p_open: NULL), flags);
    lua_pushboolean(L, _retval);
    lua_pushboolean(L, has_p_open || p_open);
    return 2;
}

static int EndTabItem(lua_State* L) {
    ImGui::EndTabItem();
    return 0;
}

static int TabItemButton(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    auto flags = (ImGuiTabItemFlags)luaL_optinteger(L, 2, lua_Integer(ImGuiTabItemFlags_None));
    auto _retval = ImGui::TabItemButton(label, flags);
    lua_pushboolean(L, _retval);
    return 1;
}

static int SetTabItemClosed(lua_State* L) {
    auto tab_or_docked_window_label = luaL_checkstring(L, 1);
    ImGui::SetTabItemClosed(tab_or_docked_window_label);
    return 0;
}

static int DockSpaceOverViewport(lua_State* L) {
    auto _retval = ImGui::DockSpaceOverViewport();
    lua_pushinteger(L, _retval);
    return 1;
}

static int SetNextWindowDockID(lua_State* L) {
    auto dock_id = (ImGuiID)luaL_checkinteger(L, 1);
    auto cond = (ImGuiCond)luaL_optinteger(L, 2, lua_Integer(ImGuiCond_None));
    ImGui::SetNextWindowDockID(dock_id, cond);
    return 0;
}

static int GetWindowDockID(lua_State* L) {
    auto _retval = ImGui::GetWindowDockID();
    lua_pushinteger(L, _retval);
    return 1;
}

static int IsWindowDocked(lua_State* L) {
    auto _retval = ImGui::IsWindowDocked();
    lua_pushboolean(L, _retval);
    return 1;
}

static int BeginDragDropSource(lua_State* L) {
    auto flags = (ImGuiDragDropFlags)luaL_optinteger(L, 1, lua_Integer(ImGuiDragDropFlags_None));
    auto _retval = ImGui::BeginDragDropSource(flags);
    lua_pushboolean(L, _retval);
    return 1;
}

static int SetDragDropPayload(lua_State* L) {
    auto type = luaL_checkstring(L, 1);
    size_t sz = 0;
    auto data = luaL_checklstring(L, 2, &sz);
    auto cond = (ImGuiCond)luaL_optinteger(L, 3, lua_Integer(ImGuiCond_None));
    auto _retval = ImGui::SetDragDropPayload(type, data, sz, cond);
    lua_pushboolean(L, _retval);
    return 1;
}

static int EndDragDropSource(lua_State* L) {
    ImGui::EndDragDropSource();
    return 0;
}

static int BeginDragDropTarget(lua_State* L) {
    auto _retval = ImGui::BeginDragDropTarget();
    lua_pushboolean(L, _retval);
    return 1;
}

static int AcceptDragDropPayload(lua_State* L) {
    auto type = luaL_checkstring(L, 1);
    auto flags = (ImGuiDragDropFlags)luaL_optinteger(L, 2, lua_Integer(ImGuiDragDropFlags_None));
    auto _retval = ImGui::AcceptDragDropPayload(type, flags);
    if (_retval != NULL) {
        lua_pushlstring(L, (const char*)_retval->Data, _retval->DataSize);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int EndDragDropTarget(lua_State* L) {
    ImGui::EndDragDropTarget();
    return 0;
}

static int GetDragDropPayload(lua_State* L) {
    auto _retval = ImGui::GetDragDropPayload();
    if (_retval != NULL) {
        lua_pushlstring(L, (const char*)_retval->Data, _retval->DataSize);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int BeginDisabled(lua_State* L) {
    auto disabled = lua_isnoneornil(L, 1)? true: !!lua_toboolean(L, 1);
    ImGui::BeginDisabled(disabled);
    return 0;
}

static int EndDisabled(lua_State* L) {
    ImGui::EndDisabled();
    return 0;
}

static int PushClipRect(lua_State* L) {
    auto clip_rect_min = ImVec2 {
        (float)luaL_checknumber(L, 1),
        (float)luaL_checknumber(L, 2),
    };
    auto clip_rect_max = ImVec2 {
        (float)luaL_checknumber(L, 3),
        (float)luaL_checknumber(L, 4),
    };
    auto intersect_with_current_clip_rect = !!lua_toboolean(L, 5);
    ImGui::PushClipRect(clip_rect_min, clip_rect_max, intersect_with_current_clip_rect);
    return 0;
}

static int PopClipRect(lua_State* L) {
    ImGui::PopClipRect();
    return 0;
}

static int SetItemDefaultFocus(lua_State* L) {
    ImGui::SetItemDefaultFocus();
    return 0;
}

static int SetKeyboardFocusHere(lua_State* L) {
    ImGui::SetKeyboardFocusHere();
    return 0;
}

static int SetKeyboardFocusHereEx(lua_State* L) {
    auto offset = (int)luaL_optinteger(L, 1, 0);
    ImGui::SetKeyboardFocusHere(offset);
    return 0;
}

static int SetNextItemAllowOverlap(lua_State* L) {
    ImGui::SetNextItemAllowOverlap();
    return 0;
}

static int IsItemHovered(lua_State* L) {
    auto flags = (ImGuiHoveredFlags)luaL_optinteger(L, 1, lua_Integer(ImGuiHoveredFlags_None));
    auto _retval = ImGui::IsItemHovered(flags);
    lua_pushboolean(L, _retval);
    return 1;
}

static int IsItemActive(lua_State* L) {
    auto _retval = ImGui::IsItemActive();
    lua_pushboolean(L, _retval);
    return 1;
}

static int IsItemFocused(lua_State* L) {
    auto _retval = ImGui::IsItemFocused();
    lua_pushboolean(L, _retval);
    return 1;
}

static int IsItemClicked(lua_State* L) {
    auto _retval = ImGui::IsItemClicked();
    lua_pushboolean(L, _retval);
    return 1;
}

static int IsItemClickedEx(lua_State* L) {
    auto mouse_button = (ImGuiMouseButton)luaL_optinteger(L, 1, lua_Integer(ImGuiMouseButton_Left));
    auto _retval = ImGui::IsItemClicked(mouse_button);
    lua_pushboolean(L, _retval);
    return 1;
}

static int IsItemVisible(lua_State* L) {
    auto _retval = ImGui::IsItemVisible();
    lua_pushboolean(L, _retval);
    return 1;
}

static int IsItemEdited(lua_State* L) {
    auto _retval = ImGui::IsItemEdited();
    lua_pushboolean(L, _retval);
    return 1;
}

static int IsItemActivated(lua_State* L) {
    auto _retval = ImGui::IsItemActivated();
    lua_pushboolean(L, _retval);
    return 1;
}

static int IsItemDeactivated(lua_State* L) {
    auto _retval = ImGui::IsItemDeactivated();
    lua_pushboolean(L, _retval);
    return 1;
}

static int IsItemDeactivatedAfterEdit(lua_State* L) {
    auto _retval = ImGui::IsItemDeactivatedAfterEdit();
    lua_pushboolean(L, _retval);
    return 1;
}

static int IsItemToggledOpen(lua_State* L) {
    auto _retval = ImGui::IsItemToggledOpen();
    lua_pushboolean(L, _retval);
    return 1;
}

static int IsAnyItemHovered(lua_State* L) {
    auto _retval = ImGui::IsAnyItemHovered();
    lua_pushboolean(L, _retval);
    return 1;
}

static int IsAnyItemActive(lua_State* L) {
    auto _retval = ImGui::IsAnyItemActive();
    lua_pushboolean(L, _retval);
    return 1;
}

static int IsAnyItemFocused(lua_State* L) {
    auto _retval = ImGui::IsAnyItemFocused();
    lua_pushboolean(L, _retval);
    return 1;
}

static int GetItemID(lua_State* L) {
    auto _retval = ImGui::GetItemID();
    lua_pushinteger(L, _retval);
    return 1;
}

static int GetItemRectMin(lua_State* L) {
    auto _retval = ImGui::GetItemRectMin();
    lua_pushnumber(L, _retval.x);
    lua_pushnumber(L, _retval.y);
    return 2;
}

static int GetItemRectMax(lua_State* L) {
    auto _retval = ImGui::GetItemRectMax();
    lua_pushnumber(L, _retval.x);
    lua_pushnumber(L, _retval.y);
    return 2;
}

static int GetItemRectSize(lua_State* L) {
    auto _retval = ImGui::GetItemRectSize();
    lua_pushnumber(L, _retval.x);
    lua_pushnumber(L, _retval.y);
    return 2;
}

static int IsRectVisibleBySize(lua_State* L) {
    auto size = ImVec2 {
        (float)luaL_checknumber(L, 1),
        (float)luaL_checknumber(L, 2),
    };
    auto _retval = ImGui::IsRectVisible(size);
    lua_pushboolean(L, _retval);
    return 1;
}

static int IsRectVisible(lua_State* L) {
    auto rect_min = ImVec2 {
        (float)luaL_checknumber(L, 1),
        (float)luaL_checknumber(L, 2),
    };
    auto rect_max = ImVec2 {
        (float)luaL_checknumber(L, 3),
        (float)luaL_checknumber(L, 4),
    };
    auto _retval = ImGui::IsRectVisible(rect_min, rect_max);
    lua_pushboolean(L, _retval);
    return 1;
}

static int GetTime(lua_State* L) {
    auto _retval = ImGui::GetTime();
    lua_pushnumber(L, _retval);
    return 1;
}

static int GetFrameCount(lua_State* L) {
    auto _retval = ImGui::GetFrameCount();
    lua_pushinteger(L, _retval);
    return 1;
}

static int GetStyleColorName(lua_State* L) {
    auto idx = (ImGuiCol)luaL_checkinteger(L, 1);
    auto _retval = ImGui::GetStyleColorName(idx);
    lua_pushstring(L, _retval);
    return 1;
}

static int CalcTextSize(lua_State* L) {
    auto text = luaL_checkstring(L, 1);
    auto _retval = ImGui::CalcTextSize(text);
    lua_pushnumber(L, _retval.x);
    lua_pushnumber(L, _retval.y);
    return 2;
}

static int CalcTextSizeEx(lua_State* L) {
    auto text = luaL_checkstring(L, 1);
    auto text_end = luaL_optstring(L, 2, NULL);
    auto hide_text_after_double_hash = lua_isnoneornil(L, 3)? false: !!lua_toboolean(L, 3);
    auto wrap_width = (float)luaL_optnumber(L, 4, -1.0f);
    auto _retval = ImGui::CalcTextSize(text, text_end, hide_text_after_double_hash, wrap_width);
    lua_pushnumber(L, _retval.x);
    lua_pushnumber(L, _retval.y);
    return 2;
}

static int ColorConvertU32ToFloat4(lua_State* L) {
    auto in = (ImU32)luaL_checkinteger(L, 1);
    auto _retval = ImGui::ColorConvertU32ToFloat4(in);
    lua_pushnumber(L, _retval.x);
    lua_pushnumber(L, _retval.y);
    lua_pushnumber(L, _retval.z);
    lua_pushnumber(L, _retval.w);
    return 4;
}

static int ColorConvertFloat4ToU32(lua_State* L) {
    auto in = ImVec4 {
        (float)luaL_checknumber(L, 1),
        (float)luaL_checknumber(L, 2),
        (float)luaL_checknumber(L, 3),
        (float)luaL_checknumber(L, 4),
    };
    auto _retval = ImGui::ColorConvertFloat4ToU32(in);
    lua_pushinteger(L, _retval);
    return 1;
}

static int IsKeyDown(lua_State* L) {
    auto key = (ImGuiKey)luaL_checkinteger(L, 1);
    auto _retval = ImGui::IsKeyDown(key);
    lua_pushboolean(L, _retval);
    return 1;
}

static int IsKeyPressed(lua_State* L) {
    auto key = (ImGuiKey)luaL_checkinteger(L, 1);
    auto _retval = ImGui::IsKeyPressed(key);
    lua_pushboolean(L, _retval);
    return 1;
}

static int IsKeyPressedEx(lua_State* L) {
    auto key = (ImGuiKey)luaL_checkinteger(L, 1);
    auto repeat = lua_isnoneornil(L, 2)? true: !!lua_toboolean(L, 2);
    auto _retval = ImGui::IsKeyPressed(key, repeat);
    lua_pushboolean(L, _retval);
    return 1;
}

static int IsKeyReleased(lua_State* L) {
    auto key = (ImGuiKey)luaL_checkinteger(L, 1);
    auto _retval = ImGui::IsKeyReleased(key);
    lua_pushboolean(L, _retval);
    return 1;
}

static int IsKeyChordPressed(lua_State* L) {
    auto key_chord = (ImGuiKeyChord)luaL_checkinteger(L, 1);
    auto _retval = ImGui::IsKeyChordPressed(key_chord);
    lua_pushboolean(L, _retval);
    return 1;
}

static int GetKeyPressedAmount(lua_State* L) {
    auto key = (ImGuiKey)luaL_checkinteger(L, 1);
    auto repeat_delay = (float)luaL_checknumber(L, 2);
    auto rate = (float)luaL_checknumber(L, 3);
    auto _retval = ImGui::GetKeyPressedAmount(key, repeat_delay, rate);
    lua_pushinteger(L, _retval);
    return 1;
}

static int GetKeyName(lua_State* L) {
    auto key = (ImGuiKey)luaL_checkinteger(L, 1);
    auto _retval = ImGui::GetKeyName(key);
    lua_pushstring(L, _retval);
    return 1;
}

static int SetNextFrameWantCaptureKeyboard(lua_State* L) {
    auto want_capture_keyboard = !!lua_toboolean(L, 1);
    ImGui::SetNextFrameWantCaptureKeyboard(want_capture_keyboard);
    return 0;
}

static int IsMouseDown(lua_State* L) {
    auto button = (ImGuiMouseButton)luaL_checkinteger(L, 1);
    auto _retval = ImGui::IsMouseDown(button);
    lua_pushboolean(L, _retval);
    return 1;
}

static int IsMouseClicked(lua_State* L) {
    auto button = (ImGuiMouseButton)luaL_checkinteger(L, 1);
    auto _retval = ImGui::IsMouseClicked(button);
    lua_pushboolean(L, _retval);
    return 1;
}

static int IsMouseClickedEx(lua_State* L) {
    auto button = (ImGuiMouseButton)luaL_checkinteger(L, 1);
    auto repeat = lua_isnoneornil(L, 2)? false: !!lua_toboolean(L, 2);
    auto _retval = ImGui::IsMouseClicked(button, repeat);
    lua_pushboolean(L, _retval);
    return 1;
}

static int IsMouseReleased(lua_State* L) {
    auto button = (ImGuiMouseButton)luaL_checkinteger(L, 1);
    auto _retval = ImGui::IsMouseReleased(button);
    lua_pushboolean(L, _retval);
    return 1;
}

static int IsMouseDoubleClicked(lua_State* L) {
    auto button = (ImGuiMouseButton)luaL_checkinteger(L, 1);
    auto _retval = ImGui::IsMouseDoubleClicked(button);
    lua_pushboolean(L, _retval);
    return 1;
}

static int GetMouseClickedCount(lua_State* L) {
    auto button = (ImGuiMouseButton)luaL_checkinteger(L, 1);
    auto _retval = ImGui::GetMouseClickedCount(button);
    lua_pushinteger(L, _retval);
    return 1;
}

static int IsMouseHoveringRect(lua_State* L) {
    auto r_min = ImVec2 {
        (float)luaL_checknumber(L, 1),
        (float)luaL_checknumber(L, 2),
    };
    auto r_max = ImVec2 {
        (float)luaL_checknumber(L, 3),
        (float)luaL_checknumber(L, 4),
    };
    auto _retval = ImGui::IsMouseHoveringRect(r_min, r_max);
    lua_pushboolean(L, _retval);
    return 1;
}

static int IsMouseHoveringRectEx(lua_State* L) {
    auto r_min = ImVec2 {
        (float)luaL_checknumber(L, 1),
        (float)luaL_checknumber(L, 2),
    };
    auto r_max = ImVec2 {
        (float)luaL_checknumber(L, 3),
        (float)luaL_checknumber(L, 4),
    };
    auto clip = lua_isnoneornil(L, 5)? true: !!lua_toboolean(L, 5);
    auto _retval = ImGui::IsMouseHoveringRect(r_min, r_max, clip);
    lua_pushboolean(L, _retval);
    return 1;
}

static int IsAnyMouseDown(lua_State* L) {
    auto _retval = ImGui::IsAnyMouseDown();
    lua_pushboolean(L, _retval);
    return 1;
}

static int GetMousePos(lua_State* L) {
    auto _retval = ImGui::GetMousePos();
    lua_pushnumber(L, _retval.x);
    lua_pushnumber(L, _retval.y);
    return 2;
}

static int GetMousePosOnOpeningCurrentPopup(lua_State* L) {
    auto _retval = ImGui::GetMousePosOnOpeningCurrentPopup();
    lua_pushnumber(L, _retval.x);
    lua_pushnumber(L, _retval.y);
    return 2;
}

static int IsMouseDragging(lua_State* L) {
    auto button = (ImGuiMouseButton)luaL_checkinteger(L, 1);
    auto lock_threshold = (float)luaL_optnumber(L, 2, -1.0f);
    auto _retval = ImGui::IsMouseDragging(button, lock_threshold);
    lua_pushboolean(L, _retval);
    return 1;
}

static int GetMouseDragDelta(lua_State* L) {
    auto button = (ImGuiMouseButton)luaL_optinteger(L, 1, lua_Integer(ImGuiMouseButton_Left));
    auto lock_threshold = (float)luaL_optnumber(L, 2, -1.0f);
    auto _retval = ImGui::GetMouseDragDelta(button, lock_threshold);
    lua_pushnumber(L, _retval.x);
    lua_pushnumber(L, _retval.y);
    return 2;
}

static int ResetMouseDragDelta(lua_State* L) {
    ImGui::ResetMouseDragDelta();
    return 0;
}

static int ResetMouseDragDeltaEx(lua_State* L) {
    auto button = (ImGuiMouseButton)luaL_optinteger(L, 1, lua_Integer(ImGuiMouseButton_Left));
    ImGui::ResetMouseDragDelta(button);
    return 0;
}

static int GetMouseCursor(lua_State* L) {
    auto _retval = ImGui::GetMouseCursor();
    lua_pushinteger(L, _retval);
    return 1;
}

static int SetMouseCursor(lua_State* L) {
    auto cursor_type = (ImGuiMouseCursor)luaL_checkinteger(L, 1);
    ImGui::SetMouseCursor(cursor_type);
    return 0;
}

static int SetNextFrameWantCaptureMouse(lua_State* L) {
    auto want_capture_mouse = !!lua_toboolean(L, 1);
    ImGui::SetNextFrameWantCaptureMouse(want_capture_mouse);
    return 0;
}

static int GetClipboardText(lua_State* L) {
    auto _retval = ImGui::GetClipboardText();
    lua_pushstring(L, _retval);
    return 1;
}

static int SetClipboardText(lua_State* L) {
    auto text = luaL_checkstring(L, 1);
    ImGui::SetClipboardText(text);
    return 0;
}

static int LoadIniSettingsFromDisk(lua_State* L) {
    auto ini_filename = luaL_checkstring(L, 1);
    ImGui::LoadIniSettingsFromDisk(ini_filename);
    return 0;
}

static int LoadIniSettingsFromMemory(lua_State* L) {
    size_t ini_size = 0;
    auto ini_data = luaL_checklstring(L, 1, &ini_size);
    ImGui::LoadIniSettingsFromMemory(ini_data, ini_size);
    return 0;
}

static int SaveIniSettingsToDisk(lua_State* L) {
    auto ini_filename = luaL_checkstring(L, 1);
    ImGui::SaveIniSettingsToDisk(ini_filename);
    return 0;
}

static int SaveIniSettingsToMemory(lua_State* L) {
    bool has_out_ini_size = !lua_isnil(L, 1);
    size_t out_ini_size = 0;
    auto _retval = ImGui::SaveIniSettingsToMemory((has_out_ini_size? &out_ini_size: NULL));
    lua_pushstring(L, _retval);
    has_out_ini_size? lua_pushinteger(L, out_ini_size): lua_pushnil(L);
    return 2;
}

static int GetKeyIndex(lua_State* L) {
    auto key = (ImGuiKey)luaL_checkinteger(L, 1);
    auto _retval = ImGui::GetKeyIndex(key);
    lua_pushinteger(L, _retval);
    return 1;
}

void init(lua_State* L) {
    luaL_Reg funcs[] = {
        { "ColorEdit3", ColorEdit3 },
        { "ColorEdit4", ColorEdit4 },
        { "ColorPicker3", ColorPicker3 },
        { "ColorButton", ColorButton },
        { "ColorButtonEx", ColorButtonEx },
        { "SetColorEditOptions", SetColorEditOptions },
        { "TreeNode", TreeNode },
        { "TreeNodeStr", TreeNodeStr },
        { "TreeNodePtr", TreeNodePtr },
        { "TreeNodeEx", TreeNodeEx },
        { "TreeNodeExStr", TreeNodeExStr },
        { "TreeNodeExPtr", TreeNodeExPtr },
        { "TreePush", TreePush },
        { "TreePushPtr", TreePushPtr },
        { "TreePop", TreePop },
        { "GetTreeNodeToLabelSpacing", GetTreeNodeToLabelSpacing },
        { "CollapsingHeader", CollapsingHeader },
        { "CollapsingHeaderBoolPtr", CollapsingHeaderBoolPtr },
        { "SetNextItemOpen", SetNextItemOpen },
        { "Selectable", Selectable },
        { "SelectableEx", SelectableEx },
        { "SelectableBoolPtr", SelectableBoolPtr },
        { "SelectableBoolPtrEx", SelectableBoolPtrEx },
        { "BeginListBox", BeginListBox },
        { "EndListBox", EndListBox },
        { "BeginMenuBar", BeginMenuBar },
        { "EndMenuBar", EndMenuBar },
        { "BeginMainMenuBar", BeginMainMenuBar },
        { "EndMainMenuBar", EndMainMenuBar },
        { "BeginMenu", BeginMenu },
        { "BeginMenuEx", BeginMenuEx },
        { "EndMenu", EndMenu },
        { "MenuItem", MenuItem },
        { "MenuItemEx", MenuItemEx },
        { "MenuItemBoolPtr", MenuItemBoolPtr },
        { "BeginTooltip", BeginTooltip },
        { "EndTooltip", EndTooltip },
        { "SetTooltip", SetTooltip },
        { "BeginItemTooltip", BeginItemTooltip },
        { "SetItemTooltip", SetItemTooltip },
        { "BeginPopup", BeginPopup },
        { "BeginPopupModal", BeginPopupModal },
        { "EndPopup", EndPopup },
        { "OpenPopup", OpenPopup },
        { "OpenPopupID", OpenPopupID },
        { "OpenPopupOnItemClick", OpenPopupOnItemClick },
        { "CloseCurrentPopup", CloseCurrentPopup },
        { "BeginPopupContextItem", BeginPopupContextItem },
        { "BeginPopupContextItemEx", BeginPopupContextItemEx },
        { "BeginPopupContextWindow", BeginPopupContextWindow },
        { "BeginPopupContextWindowEx", BeginPopupContextWindowEx },
        { "BeginPopupContextVoid", BeginPopupContextVoid },
        { "BeginPopupContextVoidEx", BeginPopupContextVoidEx },
        { "IsPopupOpen", IsPopupOpen },
        { "BeginTable", BeginTable },
        { "BeginTableEx", BeginTableEx },
        { "EndTable", EndTable },
        { "TableNextRow", TableNextRow },
        { "TableNextRowEx", TableNextRowEx },
        { "TableNextColumn", TableNextColumn },
        { "TableSetColumnIndex", TableSetColumnIndex },
        { "TableSetupColumn", TableSetupColumn },
        { "TableSetupColumnEx", TableSetupColumnEx },
        { "TableSetupScrollFreeze", TableSetupScrollFreeze },
        { "TableHeader", TableHeader },
        { "TableHeadersRow", TableHeadersRow },
        { "TableAngledHeadersRow", TableAngledHeadersRow },
        { "TableGetColumnCount", TableGetColumnCount },
        { "TableGetColumnIndex", TableGetColumnIndex },
        { "TableGetRowIndex", TableGetRowIndex },
        { "TableGetColumnName", TableGetColumnName },
        { "TableGetColumnFlags", TableGetColumnFlags },
        { "TableSetColumnEnabled", TableSetColumnEnabled },
        { "TableSetBgColor", TableSetBgColor },
        { "BeginTabBar", BeginTabBar },
        { "EndTabBar", EndTabBar },
        { "BeginTabItem", BeginTabItem },
        { "EndTabItem", EndTabItem },
        { "TabItemButton", TabItemButton },
        { "SetTabItemClosed", SetTabItemClosed },
        { "DockSpaceOverViewport", DockSpaceOverViewport },
        { "SetNextWindowDockID", SetNextWindowDockID },
        { "GetWindowDockID", GetWindowDockID },
        { "IsWindowDocked", IsWindowDocked },
        { "BeginDragDropSource", BeginDragDropSource },
        { "SetDragDropPayload", SetDragDropPayload },
        { "EndDragDropSource", EndDragDropSource },
        { "BeginDragDropTarget", BeginDragDropTarget },
        { "AcceptDragDropPayload", AcceptDragDropPayload },
        { "EndDragDropTarget", EndDragDropTarget },
        { "GetDragDropPayload", GetDragDropPayload },
        { "BeginDisabled", BeginDisabled },
        { "EndDisabled", EndDisabled },
        { "PushClipRect", PushClipRect },
        { "PopClipRect", PopClipRect },
        { "SetItemDefaultFocus", SetItemDefaultFocus },
        { "SetKeyboardFocusHere", SetKeyboardFocusHere },
        { "SetKeyboardFocusHereEx", SetKeyboardFocusHereEx },
        { "SetNextItemAllowOverlap", SetNextItemAllowOverlap },
        { "IsItemHovered", IsItemHovered },
        { "IsItemActive", IsItemActive },
        { "IsItemFocused", IsItemFocused },
        { "IsItemClicked", IsItemClicked },
        { "IsItemClickedEx", IsItemClickedEx },
        { "IsItemVisible", IsItemVisible },
        { "IsItemEdited", IsItemEdited },
        { "IsItemActivated", IsItemActivated },
        { "IsItemDeactivated", IsItemDeactivated },
        { "IsItemDeactivatedAfterEdit", IsItemDeactivatedAfterEdit },
        { "IsItemToggledOpen", IsItemToggledOpen },
        { "IsAnyItemHovered", IsAnyItemHovered },
        { "IsAnyItemActive", IsAnyItemActive },
        { "IsAnyItemFocused", IsAnyItemFocused },
        { "GetItemID", GetItemID },
        { "GetItemRectMin", GetItemRectMin },
        { "GetItemRectMax", GetItemRectMax },
        { "GetItemRectSize", GetItemRectSize },
        { "IsRectVisibleBySize", IsRectVisibleBySize },
        { "IsRectVisible", IsRectVisible },
        { "GetTime", GetTime },
        { "GetFrameCount", GetFrameCount },
        { "GetStyleColorName", GetStyleColorName },
        { "CalcTextSize", CalcTextSize },
        { "CalcTextSizeEx", CalcTextSizeEx },
        { "ColorConvertU32ToFloat4", ColorConvertU32ToFloat4 },
        { "ColorConvertFloat4ToU32", ColorConvertFloat4ToU32 },
        { "IsKeyDown", IsKeyDown },
        { "IsKeyPressed", IsKeyPressed },
        { "IsKeyPressedEx", IsKeyPressedEx },
        { "IsKeyReleased", IsKeyReleased },
        { "IsKeyChordPressed", IsKeyChordPressed },
        { "GetKeyPressedAmount", GetKeyPressedAmount },
        { "GetKeyName", GetKeyName },
        { "SetNextFrameWantCaptureKeyboard", SetNextFrameWantCaptureKeyboard },
        { "IsMouseDown", IsMouseDown },
        { "IsMouseClicked", IsMouseClicked },
        { "IsMouseClickedEx", IsMouseClickedEx },
        { "IsMouseReleased", IsMouseReleased },
        { "IsMouseDoubleClicked", IsMouseDoubleClicked },
        { "GetMouseClickedCount", GetMouseClickedCount },
        { "IsMouseHoveringRect", IsMouseHoveringRect },
        { "IsMouseHoveringRectEx", IsMouseHoveringRectEx },
        { "IsAnyMouseDown", IsAnyMouseDown },
        { "GetMousePos", GetMousePos },
        { "GetMousePosOnOpeningCurrentPopup", GetMousePosOnOpeningCurrentPopup },
        { "IsMouseDragging", IsMouseDragging },
        { "GetMouseDragDelta", GetMouseDragDelta },
        { "ResetMouseDragDelta", ResetMouseDragDelta },
        { "ResetMouseDragDeltaEx", ResetMouseDragDeltaEx },
        { "GetMouseCursor", GetMouseCursor },
        { "SetMouseCursor", SetMouseCursor },
        { "SetNextFrameWantCaptureMouse", SetNextFrameWantCaptureMouse },
        { "GetClipboardText", GetClipboardText },
        { "SetClipboardText", SetClipboardText },
        { "LoadIniSettingsFromDisk", LoadIniSettingsFromDisk },
        { "LoadIniSettingsFromMemory", LoadIniSettingsFromMemory },
        { "SaveIniSettingsToDisk", SaveIniSettingsToDisk },
        { "SaveIniSettingsToMemory", SaveIniSettingsToMemory },
        { "GetKeyIndex", GetKeyIndex },
        { NULL, NULL },
    };
    luaL_setfuncs(L, funcs, 0);
    find_str_format(L);
}
}
