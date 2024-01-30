//
// Automatically generated file; DO NOT EDIT.
//
#include <imgui.h>
#include <lua.hpp>

namespace imgui_lua {

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
    auto outer_size = ImVec2 { (float)luaL_optnumber(L, 4, 0.f), (float)luaL_optnumber(L, 5, 0.f) };
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
    auto has_p_open = !lua_isnil(L, 2);
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
    auto clip_rect_min = ImVec2 { (float)luaL_checknumber(L, 1), (float)luaL_checknumber(L, 2) };
    auto clip_rect_max = ImVec2 { (float)luaL_checknumber(L, 3), (float)luaL_checknumber(L, 4) };
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

void init(lua_State* L) {
    luaL_Reg funcs[] = {
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
        { "CalcTextSize", CalcTextSize },
        { "CalcTextSizeEx", CalcTextSizeEx },
        { "IsKeyDown", IsKeyDown },
        { "IsKeyPressed", IsKeyPressed },
        { "IsKeyPressedEx", IsKeyPressedEx },
        { "IsKeyReleased", IsKeyReleased },
        { "IsKeyChordPressed", IsKeyChordPressed },
        { NULL, NULL },
    };
    luaL_setfuncs(L, funcs, 0);
}
}
