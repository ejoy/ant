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

static auto field_tointeger(lua_State* L, int idx, lua_Integer i) {
    lua_geti(L, idx, i);
    auto v = luaL_checknumber(L, -1);
    lua_pop(L, 1);
    return v;
}

static auto field_tonumber(lua_State* L, int idx, lua_Integer i) {
    lua_geti(L, idx, i);
    auto v = luaL_checknumber(L, -1);
    lua_pop(L, 1);
    return v;
}

static auto field_toboolean(lua_State* L, int idx, lua_Integer i) {
    lua_geti(L, idx, i);
    bool v = !!lua_toboolean(L, -1);
    lua_pop(L, 1);
    return v;
}

static int Begin(lua_State* L) {
    auto name = luaL_checkstring(L, 1);
    bool has_p_open = !lua_isnil(L, 2);
    bool p_open = true;
    auto flags = (ImGuiWindowFlags)luaL_optinteger(L, 3, lua_Integer(ImGuiWindowFlags_None));
    auto _retval = ImGui::Begin(name, (has_p_open? &p_open: NULL), flags);
    lua_pushboolean(L, _retval);
    lua_pushboolean(L, has_p_open || p_open);
    return 2;
}

static int End(lua_State* L) {
    ImGui::End();
    return 0;
}

static int BeginChild(lua_State* L) {
    auto str_id = luaL_checkstring(L, 1);
    auto size = ImVec2 {
        (float)luaL_optnumber(L, 2, 0),
        (float)luaL_optnumber(L, 3, 0),
    };
    auto child_flags = (ImGuiChildFlags)luaL_optinteger(L, 4, lua_Integer(ImGuiChildFlags_None));
    auto window_flags = (ImGuiWindowFlags)luaL_optinteger(L, 5, lua_Integer(ImGuiWindowFlags_None));
    auto _retval = ImGui::BeginChild(str_id, size, child_flags, window_flags);
    lua_pushboolean(L, _retval);
    return 1;
}

static int BeginChildID(lua_State* L) {
    auto id = (ImGuiID)luaL_checkinteger(L, 1);
    auto size = ImVec2 {
        (float)luaL_optnumber(L, 2, 0),
        (float)luaL_optnumber(L, 3, 0),
    };
    auto child_flags = (ImGuiChildFlags)luaL_optinteger(L, 4, lua_Integer(ImGuiChildFlags_None));
    auto window_flags = (ImGuiWindowFlags)luaL_optinteger(L, 5, lua_Integer(ImGuiWindowFlags_None));
    auto _retval = ImGui::BeginChild(id, size, child_flags, window_flags);
    lua_pushboolean(L, _retval);
    return 1;
}

static int EndChild(lua_State* L) {
    ImGui::EndChild();
    return 0;
}

static int IsWindowAppearing(lua_State* L) {
    auto _retval = ImGui::IsWindowAppearing();
    lua_pushboolean(L, _retval);
    return 1;
}

static int IsWindowCollapsed(lua_State* L) {
    auto _retval = ImGui::IsWindowCollapsed();
    lua_pushboolean(L, _retval);
    return 1;
}

static int IsWindowFocused(lua_State* L) {
    auto flags = (ImGuiFocusedFlags)luaL_optinteger(L, 1, lua_Integer(ImGuiFocusedFlags_None));
    auto _retval = ImGui::IsWindowFocused(flags);
    lua_pushboolean(L, _retval);
    return 1;
}

static int IsWindowHovered(lua_State* L) {
    auto flags = (ImGuiHoveredFlags)luaL_optinteger(L, 1, lua_Integer(ImGuiHoveredFlags_None));
    auto _retval = ImGui::IsWindowHovered(flags);
    lua_pushboolean(L, _retval);
    return 1;
}

static int GetWindowDpiScale(lua_State* L) {
    auto _retval = ImGui::GetWindowDpiScale();
    lua_pushnumber(L, _retval);
    return 1;
}

static int GetWindowPos(lua_State* L) {
    auto _retval = ImGui::GetWindowPos();
    lua_pushnumber(L, _retval.x);
    lua_pushnumber(L, _retval.y);
    return 2;
}

static int GetWindowSize(lua_State* L) {
    auto _retval = ImGui::GetWindowSize();
    lua_pushnumber(L, _retval.x);
    lua_pushnumber(L, _retval.y);
    return 2;
}

static int GetWindowWidth(lua_State* L) {
    auto _retval = ImGui::GetWindowWidth();
    lua_pushnumber(L, _retval);
    return 1;
}

static int GetWindowHeight(lua_State* L) {
    auto _retval = ImGui::GetWindowHeight();
    lua_pushnumber(L, _retval);
    return 1;
}

static int SetNextWindowPos(lua_State* L) {
    auto pos = ImVec2 {
        (float)luaL_checknumber(L, 1),
        (float)luaL_checknumber(L, 2),
    };
    auto cond = (ImGuiCond)luaL_optinteger(L, 3, lua_Integer(ImGuiCond_None));
    ImGui::SetNextWindowPos(pos, cond);
    return 0;
}

static int SetNextWindowPosEx(lua_State* L) {
    auto pos = ImVec2 {
        (float)luaL_checknumber(L, 1),
        (float)luaL_checknumber(L, 2),
    };
    auto cond = (ImGuiCond)luaL_optinteger(L, 3, lua_Integer(ImGuiCond_None));
    auto pivot = ImVec2 {
        (float)luaL_optnumber(L, 4, 0),
        (float)luaL_optnumber(L, 5, 0),
    };
    ImGui::SetNextWindowPos(pos, cond, pivot);
    return 0;
}

static int SetNextWindowSize(lua_State* L) {
    auto size = ImVec2 {
        (float)luaL_checknumber(L, 1),
        (float)luaL_checknumber(L, 2),
    };
    auto cond = (ImGuiCond)luaL_optinteger(L, 3, lua_Integer(ImGuiCond_None));
    ImGui::SetNextWindowSize(size, cond);
    return 0;
}

static int SetNextWindowContentSize(lua_State* L) {
    auto size = ImVec2 {
        (float)luaL_checknumber(L, 1),
        (float)luaL_checknumber(L, 2),
    };
    ImGui::SetNextWindowContentSize(size);
    return 0;
}

static int SetNextWindowCollapsed(lua_State* L) {
    auto collapsed = !!lua_toboolean(L, 1);
    auto cond = (ImGuiCond)luaL_optinteger(L, 2, lua_Integer(ImGuiCond_None));
    ImGui::SetNextWindowCollapsed(collapsed, cond);
    return 0;
}

static int SetNextWindowFocus(lua_State* L) {
    ImGui::SetNextWindowFocus();
    return 0;
}

static int SetNextWindowScroll(lua_State* L) {
    auto scroll = ImVec2 {
        (float)luaL_checknumber(L, 1),
        (float)luaL_checknumber(L, 2),
    };
    ImGui::SetNextWindowScroll(scroll);
    return 0;
}

static int SetNextWindowBgAlpha(lua_State* L) {
    auto alpha = (float)luaL_checknumber(L, 1);
    ImGui::SetNextWindowBgAlpha(alpha);
    return 0;
}

static int SetNextWindowViewport(lua_State* L) {
    auto viewport_id = (ImGuiID)luaL_checkinteger(L, 1);
    ImGui::SetNextWindowViewport(viewport_id);
    return 0;
}

static int SetWindowPos(lua_State* L) {
    auto pos = ImVec2 {
        (float)luaL_checknumber(L, 1),
        (float)luaL_checknumber(L, 2),
    };
    auto cond = (ImGuiCond)luaL_optinteger(L, 3, lua_Integer(ImGuiCond_None));
    ImGui::SetWindowPos(pos, cond);
    return 0;
}

static int SetWindowSize(lua_State* L) {
    auto size = ImVec2 {
        (float)luaL_checknumber(L, 1),
        (float)luaL_checknumber(L, 2),
    };
    auto cond = (ImGuiCond)luaL_optinteger(L, 3, lua_Integer(ImGuiCond_None));
    ImGui::SetWindowSize(size, cond);
    return 0;
}

static int SetWindowCollapsed(lua_State* L) {
    auto collapsed = !!lua_toboolean(L, 1);
    auto cond = (ImGuiCond)luaL_optinteger(L, 2, lua_Integer(ImGuiCond_None));
    ImGui::SetWindowCollapsed(collapsed, cond);
    return 0;
}

static int SetWindowFocus(lua_State* L) {
    ImGui::SetWindowFocus();
    return 0;
}

static int SetWindowFontScale(lua_State* L) {
    auto scale = (float)luaL_checknumber(L, 1);
    ImGui::SetWindowFontScale(scale);
    return 0;
}

static int SetWindowPosStr(lua_State* L) {
    auto name = luaL_checkstring(L, 1);
    auto pos = ImVec2 {
        (float)luaL_checknumber(L, 2),
        (float)luaL_checknumber(L, 3),
    };
    auto cond = (ImGuiCond)luaL_optinteger(L, 4, lua_Integer(ImGuiCond_None));
    ImGui::SetWindowPos(name, pos, cond);
    return 0;
}

static int SetWindowSizeStr(lua_State* L) {
    auto name = luaL_checkstring(L, 1);
    auto size = ImVec2 {
        (float)luaL_checknumber(L, 2),
        (float)luaL_checknumber(L, 3),
    };
    auto cond = (ImGuiCond)luaL_optinteger(L, 4, lua_Integer(ImGuiCond_None));
    ImGui::SetWindowSize(name, size, cond);
    return 0;
}

static int SetWindowCollapsedStr(lua_State* L) {
    auto name = luaL_checkstring(L, 1);
    auto collapsed = !!lua_toboolean(L, 2);
    auto cond = (ImGuiCond)luaL_optinteger(L, 3, lua_Integer(ImGuiCond_None));
    ImGui::SetWindowCollapsed(name, collapsed, cond);
    return 0;
}

static int SetWindowFocusStr(lua_State* L) {
    auto name = luaL_checkstring(L, 1);
    ImGui::SetWindowFocus(name);
    return 0;
}

static int GetContentRegionAvail(lua_State* L) {
    auto _retval = ImGui::GetContentRegionAvail();
    lua_pushnumber(L, _retval.x);
    lua_pushnumber(L, _retval.y);
    return 2;
}

static int GetContentRegionMax(lua_State* L) {
    auto _retval = ImGui::GetContentRegionMax();
    lua_pushnumber(L, _retval.x);
    lua_pushnumber(L, _retval.y);
    return 2;
}

static int GetWindowContentRegionMin(lua_State* L) {
    auto _retval = ImGui::GetWindowContentRegionMin();
    lua_pushnumber(L, _retval.x);
    lua_pushnumber(L, _retval.y);
    return 2;
}

static int GetWindowContentRegionMax(lua_State* L) {
    auto _retval = ImGui::GetWindowContentRegionMax();
    lua_pushnumber(L, _retval.x);
    lua_pushnumber(L, _retval.y);
    return 2;
}

static int GetScrollX(lua_State* L) {
    auto _retval = ImGui::GetScrollX();
    lua_pushnumber(L, _retval);
    return 1;
}

static int GetScrollY(lua_State* L) {
    auto _retval = ImGui::GetScrollY();
    lua_pushnumber(L, _retval);
    return 1;
}

static int SetScrollX(lua_State* L) {
    auto scroll_x = (float)luaL_checknumber(L, 1);
    ImGui::SetScrollX(scroll_x);
    return 0;
}

static int SetScrollY(lua_State* L) {
    auto scroll_y = (float)luaL_checknumber(L, 1);
    ImGui::SetScrollY(scroll_y);
    return 0;
}

static int GetScrollMaxX(lua_State* L) {
    auto _retval = ImGui::GetScrollMaxX();
    lua_pushnumber(L, _retval);
    return 1;
}

static int GetScrollMaxY(lua_State* L) {
    auto _retval = ImGui::GetScrollMaxY();
    lua_pushnumber(L, _retval);
    return 1;
}

static int SetScrollHereX(lua_State* L) {
    auto center_x_ratio = (float)luaL_optnumber(L, 1, 0.5f);
    ImGui::SetScrollHereX(center_x_ratio);
    return 0;
}

static int SetScrollHereY(lua_State* L) {
    auto center_y_ratio = (float)luaL_optnumber(L, 1, 0.5f);
    ImGui::SetScrollHereY(center_y_ratio);
    return 0;
}

static int SetScrollFromPosX(lua_State* L) {
    auto local_x = (float)luaL_checknumber(L, 1);
    auto center_x_ratio = (float)luaL_optnumber(L, 2, 0.5f);
    ImGui::SetScrollFromPosX(local_x, center_x_ratio);
    return 0;
}

static int SetScrollFromPosY(lua_State* L) {
    auto local_y = (float)luaL_checknumber(L, 1);
    auto center_y_ratio = (float)luaL_optnumber(L, 2, 0.5f);
    ImGui::SetScrollFromPosY(local_y, center_y_ratio);
    return 0;
}

static int PopFont(lua_State* L) {
    ImGui::PopFont();
    return 0;
}

static int PushStyleColor(lua_State* L) {
    auto idx = (ImGuiCol)luaL_checkinteger(L, 1);
    auto col = (ImU32)luaL_checkinteger(L, 2);
    ImGui::PushStyleColor(idx, col);
    return 0;
}

static int PushStyleColorImVec4(lua_State* L) {
    auto idx = (ImGuiCol)luaL_checkinteger(L, 1);
    auto col = ImVec4 {
        (float)luaL_checknumber(L, 2),
        (float)luaL_checknumber(L, 3),
        (float)luaL_checknumber(L, 4),
        (float)luaL_checknumber(L, 5),
    };
    ImGui::PushStyleColor(idx, col);
    return 0;
}

static int PopStyleColor(lua_State* L) {
    ImGui::PopStyleColor();
    return 0;
}

static int PopStyleColorEx(lua_State* L) {
    auto count = (int)luaL_optinteger(L, 1, 1);
    ImGui::PopStyleColor(count);
    return 0;
}

static int PushStyleVar(lua_State* L) {
    auto idx = (ImGuiStyleVar)luaL_checkinteger(L, 1);
    auto val = (float)luaL_checknumber(L, 2);
    ImGui::PushStyleVar(idx, val);
    return 0;
}

static int PushStyleVarImVec2(lua_State* L) {
    auto idx = (ImGuiStyleVar)luaL_checkinteger(L, 1);
    auto val = ImVec2 {
        (float)luaL_checknumber(L, 2),
        (float)luaL_checknumber(L, 3),
    };
    ImGui::PushStyleVar(idx, val);
    return 0;
}

static int PopStyleVar(lua_State* L) {
    ImGui::PopStyleVar();
    return 0;
}

static int PopStyleVarEx(lua_State* L) {
    auto count = (int)luaL_optinteger(L, 1, 1);
    ImGui::PopStyleVar(count);
    return 0;
}

static int PushTabStop(lua_State* L) {
    auto tab_stop = !!lua_toboolean(L, 1);
    ImGui::PushTabStop(tab_stop);
    return 0;
}

static int PopTabStop(lua_State* L) {
    ImGui::PopTabStop();
    return 0;
}

static int PushButtonRepeat(lua_State* L) {
    auto repeat = !!lua_toboolean(L, 1);
    ImGui::PushButtonRepeat(repeat);
    return 0;
}

static int PopButtonRepeat(lua_State* L) {
    ImGui::PopButtonRepeat();
    return 0;
}

static int PushItemWidth(lua_State* L) {
    auto item_width = (float)luaL_checknumber(L, 1);
    ImGui::PushItemWidth(item_width);
    return 0;
}

static int PopItemWidth(lua_State* L) {
    ImGui::PopItemWidth();
    return 0;
}

static int SetNextItemWidth(lua_State* L) {
    auto item_width = (float)luaL_checknumber(L, 1);
    ImGui::SetNextItemWidth(item_width);
    return 0;
}

static int CalcItemWidth(lua_State* L) {
    auto _retval = ImGui::CalcItemWidth();
    lua_pushnumber(L, _retval);
    return 1;
}

static int PushTextWrapPos(lua_State* L) {
    auto wrap_local_pos_x = (float)luaL_optnumber(L, 1, 0.0f);
    ImGui::PushTextWrapPos(wrap_local_pos_x);
    return 0;
}

static int PopTextWrapPos(lua_State* L) {
    ImGui::PopTextWrapPos();
    return 0;
}

static int GetFontSize(lua_State* L) {
    auto _retval = ImGui::GetFontSize();
    lua_pushnumber(L, _retval);
    return 1;
}

static int GetFontTexUvWhitePixel(lua_State* L) {
    auto _retval = ImGui::GetFontTexUvWhitePixel();
    lua_pushnumber(L, _retval.x);
    lua_pushnumber(L, _retval.y);
    return 2;
}

static int GetColorU32(lua_State* L) {
    auto idx = (ImGuiCol)luaL_checkinteger(L, 1);
    auto _retval = ImGui::GetColorU32(idx);
    lua_pushinteger(L, _retval);
    return 1;
}

static int GetColorU32Ex(lua_State* L) {
    auto idx = (ImGuiCol)luaL_checkinteger(L, 1);
    auto alpha_mul = (float)luaL_optnumber(L, 2, 1.0f);
    auto _retval = ImGui::GetColorU32(idx, alpha_mul);
    lua_pushinteger(L, _retval);
    return 1;
}

static int GetColorU32ImVec4(lua_State* L) {
    auto col = ImVec4 {
        (float)luaL_checknumber(L, 1),
        (float)luaL_checknumber(L, 2),
        (float)luaL_checknumber(L, 3),
        (float)luaL_checknumber(L, 4),
    };
    auto _retval = ImGui::GetColorU32(col);
    lua_pushinteger(L, _retval);
    return 1;
}

static int GetColorU32ImU32(lua_State* L) {
    auto col = (ImU32)luaL_checkinteger(L, 1);
    auto _retval = ImGui::GetColorU32(col);
    lua_pushinteger(L, _retval);
    return 1;
}

static int GetCursorScreenPos(lua_State* L) {
    auto _retval = ImGui::GetCursorScreenPos();
    lua_pushnumber(L, _retval.x);
    lua_pushnumber(L, _retval.y);
    return 2;
}

static int SetCursorScreenPos(lua_State* L) {
    auto pos = ImVec2 {
        (float)luaL_checknumber(L, 1),
        (float)luaL_checknumber(L, 2),
    };
    ImGui::SetCursorScreenPos(pos);
    return 0;
}

static int GetCursorPos(lua_State* L) {
    auto _retval = ImGui::GetCursorPos();
    lua_pushnumber(L, _retval.x);
    lua_pushnumber(L, _retval.y);
    return 2;
}

static int GetCursorPosX(lua_State* L) {
    auto _retval = ImGui::GetCursorPosX();
    lua_pushnumber(L, _retval);
    return 1;
}

static int GetCursorPosY(lua_State* L) {
    auto _retval = ImGui::GetCursorPosY();
    lua_pushnumber(L, _retval);
    return 1;
}

static int SetCursorPos(lua_State* L) {
    auto local_pos = ImVec2 {
        (float)luaL_checknumber(L, 1),
        (float)luaL_checknumber(L, 2),
    };
    ImGui::SetCursorPos(local_pos);
    return 0;
}

static int SetCursorPosX(lua_State* L) {
    auto local_x = (float)luaL_checknumber(L, 1);
    ImGui::SetCursorPosX(local_x);
    return 0;
}

static int SetCursorPosY(lua_State* L) {
    auto local_y = (float)luaL_checknumber(L, 1);
    ImGui::SetCursorPosY(local_y);
    return 0;
}

static int GetCursorStartPos(lua_State* L) {
    auto _retval = ImGui::GetCursorStartPos();
    lua_pushnumber(L, _retval.x);
    lua_pushnumber(L, _retval.y);
    return 2;
}

static int Separator(lua_State* L) {
    ImGui::Separator();
    return 0;
}

static int SameLine(lua_State* L) {
    ImGui::SameLine();
    return 0;
}

static int SameLineEx(lua_State* L) {
    auto offset_from_start_x = (float)luaL_optnumber(L, 1, 0.0f);
    auto spacing = (float)luaL_optnumber(L, 2, -1.0f);
    ImGui::SameLine(offset_from_start_x, spacing);
    return 0;
}

static int NewLine(lua_State* L) {
    ImGui::NewLine();
    return 0;
}

static int Spacing(lua_State* L) {
    ImGui::Spacing();
    return 0;
}

static int Dummy(lua_State* L) {
    auto size = ImVec2 {
        (float)luaL_checknumber(L, 1),
        (float)luaL_checknumber(L, 2),
    };
    ImGui::Dummy(size);
    return 0;
}

static int Indent(lua_State* L) {
    ImGui::Indent();
    return 0;
}

static int IndentEx(lua_State* L) {
    auto indent_w = (float)luaL_optnumber(L, 1, 0.0f);
    ImGui::Indent(indent_w);
    return 0;
}

static int Unindent(lua_State* L) {
    ImGui::Unindent();
    return 0;
}

static int UnindentEx(lua_State* L) {
    auto indent_w = (float)luaL_optnumber(L, 1, 0.0f);
    ImGui::Unindent(indent_w);
    return 0;
}

static int BeginGroup(lua_State* L) {
    ImGui::BeginGroup();
    return 0;
}

static int EndGroup(lua_State* L) {
    ImGui::EndGroup();
    return 0;
}

static int AlignTextToFramePadding(lua_State* L) {
    ImGui::AlignTextToFramePadding();
    return 0;
}

static int GetTextLineHeight(lua_State* L) {
    auto _retval = ImGui::GetTextLineHeight();
    lua_pushnumber(L, _retval);
    return 1;
}

static int GetTextLineHeightWithSpacing(lua_State* L) {
    auto _retval = ImGui::GetTextLineHeightWithSpacing();
    lua_pushnumber(L, _retval);
    return 1;
}

static int GetFrameHeight(lua_State* L) {
    auto _retval = ImGui::GetFrameHeight();
    lua_pushnumber(L, _retval);
    return 1;
}

static int GetFrameHeightWithSpacing(lua_State* L) {
    auto _retval = ImGui::GetFrameHeightWithSpacing();
    lua_pushnumber(L, _retval);
    return 1;
}

static int PushID(lua_State* L) {
    auto str_id = luaL_checkstring(L, 1);
    ImGui::PushID(str_id);
    return 0;
}

static int PushIDStr(lua_State* L) {
    auto str_id_begin = luaL_checkstring(L, 1);
    auto str_id_end = luaL_checkstring(L, 2);
    ImGui::PushID(str_id_begin, str_id_end);
    return 0;
}

static int PushIDPtr(lua_State* L) {
    auto ptr_id = lua_touserdata(L, 1);
    ImGui::PushID(ptr_id);
    return 0;
}

static int PushIDInt(lua_State* L) {
    auto int_id = (int)luaL_checkinteger(L, 1);
    ImGui::PushID(int_id);
    return 0;
}

static int PopID(lua_State* L) {
    ImGui::PopID();
    return 0;
}

static int GetID(lua_State* L) {
    auto str_id = luaL_checkstring(L, 1);
    auto _retval = ImGui::GetID(str_id);
    lua_pushinteger(L, _retval);
    return 1;
}

static int GetIDStr(lua_State* L) {
    auto str_id_begin = luaL_checkstring(L, 1);
    auto str_id_end = luaL_checkstring(L, 2);
    auto _retval = ImGui::GetID(str_id_begin, str_id_end);
    lua_pushinteger(L, _retval);
    return 1;
}

static int GetIDPtr(lua_State* L) {
    auto ptr_id = lua_touserdata(L, 1);
    auto _retval = ImGui::GetID(ptr_id);
    lua_pushinteger(L, _retval);
    return 1;
}

static int Text(lua_State* L) {
    lua_pushcfunction(L, str_format);
    lua_insert(L, 1);
    lua_call(L, lua_gettop(L) - 1, 1);
    const char* _fmtstr = lua_tostring(L, -1);
    ImGui::Text("%s", _fmtstr);
    return 0;
}

static int TextColored(lua_State* L) {
    auto col = ImVec4 {
        (float)luaL_checknumber(L, 1),
        (float)luaL_checknumber(L, 2),
        (float)luaL_checknumber(L, 3),
        (float)luaL_checknumber(L, 4),
    };
    lua_pushcfunction(L, str_format);
    lua_insert(L, 5);
    lua_call(L, lua_gettop(L) - 5, 1);
    const char* _fmtstr = lua_tostring(L, -1);
    ImGui::TextColored(col, "%s", _fmtstr);
    return 0;
}

static int TextDisabled(lua_State* L) {
    lua_pushcfunction(L, str_format);
    lua_insert(L, 1);
    lua_call(L, lua_gettop(L) - 1, 1);
    const char* _fmtstr = lua_tostring(L, -1);
    ImGui::TextDisabled("%s", _fmtstr);
    return 0;
}

static int TextWrapped(lua_State* L) {
    lua_pushcfunction(L, str_format);
    lua_insert(L, 1);
    lua_call(L, lua_gettop(L) - 1, 1);
    const char* _fmtstr = lua_tostring(L, -1);
    ImGui::TextWrapped("%s", _fmtstr);
    return 0;
}

static int LabelText(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    lua_pushcfunction(L, str_format);
    lua_insert(L, 2);
    lua_call(L, lua_gettop(L) - 2, 1);
    const char* _fmtstr = lua_tostring(L, -1);
    ImGui::LabelText(label, "%s", _fmtstr);
    return 0;
}

static int BulletText(lua_State* L) {
    lua_pushcfunction(L, str_format);
    lua_insert(L, 1);
    lua_call(L, lua_gettop(L) - 1, 1);
    const char* _fmtstr = lua_tostring(L, -1);
    ImGui::BulletText("%s", _fmtstr);
    return 0;
}

static int SeparatorText(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    ImGui::SeparatorText(label);
    return 0;
}

static int Button(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    auto _retval = ImGui::Button(label);
    lua_pushboolean(L, _retval);
    return 1;
}

static int ButtonEx(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    auto size = ImVec2 {
        (float)luaL_optnumber(L, 2, 0),
        (float)luaL_optnumber(L, 3, 0),
    };
    auto _retval = ImGui::Button(label, size);
    lua_pushboolean(L, _retval);
    return 1;
}

static int SmallButton(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    auto _retval = ImGui::SmallButton(label);
    lua_pushboolean(L, _retval);
    return 1;
}

static int InvisibleButton(lua_State* L) {
    auto str_id = luaL_checkstring(L, 1);
    auto size = ImVec2 {
        (float)luaL_checknumber(L, 2),
        (float)luaL_checknumber(L, 3),
    };
    auto flags = (ImGuiButtonFlags)luaL_optinteger(L, 4, lua_Integer(ImGuiButtonFlags_None));
    auto _retval = ImGui::InvisibleButton(str_id, size, flags);
    lua_pushboolean(L, _retval);
    return 1;
}

static int ArrowButton(lua_State* L) {
    auto str_id = luaL_checkstring(L, 1);
    auto dir = (ImGuiDir)luaL_checkinteger(L, 2);
    auto _retval = ImGui::ArrowButton(str_id, dir);
    lua_pushboolean(L, _retval);
    return 1;
}

static int Checkbox(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _v_index = 2;
    bool v[] = {
        field_toboolean(L, 2, 1),
    };
    auto _retval = ImGui::Checkbox(label, v);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushboolean(L, v[0]);
        lua_seti(L, _v_index, 1);
    };
    return 1;
}

static int CheckboxFlagsIntPtr(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _flags_index = 2;
    int flags[] = {
        (int)field_tointeger(L, 2, 1),
    };
    auto flags_value = (int)luaL_checkinteger(L, 3);
    auto _retval = ImGui::CheckboxFlags(label, flags, flags_value);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushinteger(L, flags[0]);
        lua_seti(L, _flags_index, 1);
    };
    return 1;
}

static int RadioButton(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    auto active = !!lua_toboolean(L, 2);
    auto _retval = ImGui::RadioButton(label, active);
    lua_pushboolean(L, _retval);
    return 1;
}

static int RadioButtonIntPtr(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _v_index = 2;
    int v[] = {
        (int)field_tointeger(L, 2, 1),
    };
    auto v_button = (int)luaL_checkinteger(L, 3);
    auto _retval = ImGui::RadioButton(label, v, v_button);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushinteger(L, v[0]);
        lua_seti(L, _v_index, 1);
    };
    return 1;
}

static int ProgressBar(lua_State* L) {
    auto fraction = (float)luaL_checknumber(L, 1);
    auto size_arg = ImVec2 {
        (float)luaL_optnumber(L, 2, -FLT_MIN),
        (float)luaL_optnumber(L, 3, 0),
    };
    auto overlay = luaL_optstring(L, 4, NULL);
    ImGui::ProgressBar(fraction, size_arg, overlay);
    return 0;
}

static int Bullet(lua_State* L) {
    ImGui::Bullet();
    return 0;
}

static int BeginCombo(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    auto preview_value = luaL_checkstring(L, 2);
    auto flags = (ImGuiComboFlags)luaL_optinteger(L, 3, lua_Integer(ImGuiComboFlags_None));
    auto _retval = ImGui::BeginCombo(label, preview_value, flags);
    lua_pushboolean(L, _retval);
    return 1;
}

static int EndCombo(lua_State* L) {
    ImGui::EndCombo();
    return 0;
}

static int Combo(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _current_item_index = 2;
    int current_item[] = {
        (int)field_tointeger(L, 2, 1),
    };
    auto items_separated_by_zeros = luaL_checkstring(L, 3);
    auto _retval = ImGui::Combo(label, current_item, items_separated_by_zeros);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushinteger(L, current_item[0]);
        lua_seti(L, _current_item_index, 1);
    };
    return 1;
}

static int ComboEx(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _current_item_index = 2;
    int current_item[] = {
        (int)field_tointeger(L, 2, 1),
    };
    auto items_separated_by_zeros = luaL_checkstring(L, 3);
    auto popup_max_height_in_items = (int)luaL_optinteger(L, 4, -1);
    auto _retval = ImGui::Combo(label, current_item, items_separated_by_zeros, popup_max_height_in_items);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushinteger(L, current_item[0]);
        lua_seti(L, _current_item_index, 1);
    };
    return 1;
}

static int DragFloat(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _v_index = 2;
    float v[] = {
        (float)field_tonumber(L, 2, 1),
    };
    auto _retval = ImGui::DragFloat(label, v);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushnumber(L, v[0]);
        lua_seti(L, _v_index, 1);
    };
    return 1;
}

static int DragFloatEx(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _v_index = 2;
    float v[] = {
        (float)field_tonumber(L, 2, 1),
    };
    auto v_speed = (float)luaL_optnumber(L, 3, 1.0f);
    auto v_min = (float)luaL_optnumber(L, 4, 0.0f);
    auto v_max = (float)luaL_optnumber(L, 5, 0.0f);
    auto format = luaL_optstring(L, 6, "%.3f");
    auto flags = (ImGuiSliderFlags)luaL_optinteger(L, 7, lua_Integer(ImGuiSliderFlags_None));
    auto _retval = ImGui::DragFloat(label, v, v_speed, v_min, v_max, format, flags);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushnumber(L, v[0]);
        lua_seti(L, _v_index, 1);
    };
    return 1;
}

static int DragFloat2(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _v_index = 2;
    float v[] = {
        (float)field_tonumber(L, 2, 1),
        (float)field_tonumber(L, 2, 2),
    };
    auto _retval = ImGui::DragFloat2(label, v);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushnumber(L, v[0]);
        lua_seti(L, _v_index, 1);
        lua_pushnumber(L, v[1]);
        lua_seti(L, _v_index, 2);
    };
    return 1;
}

static int DragFloat2Ex(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _v_index = 2;
    float v[] = {
        (float)field_tonumber(L, 2, 1),
        (float)field_tonumber(L, 2, 2),
    };
    auto v_speed = (float)luaL_optnumber(L, 3, 1.0f);
    auto v_min = (float)luaL_optnumber(L, 4, 0.0f);
    auto v_max = (float)luaL_optnumber(L, 5, 0.0f);
    auto format = luaL_optstring(L, 6, "%.3f");
    auto flags = (ImGuiSliderFlags)luaL_optinteger(L, 7, lua_Integer(ImGuiSliderFlags_None));
    auto _retval = ImGui::DragFloat2(label, v, v_speed, v_min, v_max, format, flags);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushnumber(L, v[0]);
        lua_seti(L, _v_index, 1);
        lua_pushnumber(L, v[1]);
        lua_seti(L, _v_index, 2);
    };
    return 1;
}

static int DragFloat3(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _v_index = 2;
    float v[] = {
        (float)field_tonumber(L, 2, 1),
        (float)field_tonumber(L, 2, 2),
        (float)field_tonumber(L, 2, 3),
    };
    auto _retval = ImGui::DragFloat3(label, v);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushnumber(L, v[0]);
        lua_seti(L, _v_index, 1);
        lua_pushnumber(L, v[1]);
        lua_seti(L, _v_index, 2);
        lua_pushnumber(L, v[2]);
        lua_seti(L, _v_index, 3);
    };
    return 1;
}

static int DragFloat3Ex(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _v_index = 2;
    float v[] = {
        (float)field_tonumber(L, 2, 1),
        (float)field_tonumber(L, 2, 2),
        (float)field_tonumber(L, 2, 3),
    };
    auto v_speed = (float)luaL_optnumber(L, 3, 1.0f);
    auto v_min = (float)luaL_optnumber(L, 4, 0.0f);
    auto v_max = (float)luaL_optnumber(L, 5, 0.0f);
    auto format = luaL_optstring(L, 6, "%.3f");
    auto flags = (ImGuiSliderFlags)luaL_optinteger(L, 7, lua_Integer(ImGuiSliderFlags_None));
    auto _retval = ImGui::DragFloat3(label, v, v_speed, v_min, v_max, format, flags);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushnumber(L, v[0]);
        lua_seti(L, _v_index, 1);
        lua_pushnumber(L, v[1]);
        lua_seti(L, _v_index, 2);
        lua_pushnumber(L, v[2]);
        lua_seti(L, _v_index, 3);
    };
    return 1;
}

static int DragFloat4(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _v_index = 2;
    float v[] = {
        (float)field_tonumber(L, 2, 1),
        (float)field_tonumber(L, 2, 2),
        (float)field_tonumber(L, 2, 3),
        (float)field_tonumber(L, 2, 4),
    };
    auto _retval = ImGui::DragFloat4(label, v);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushnumber(L, v[0]);
        lua_seti(L, _v_index, 1);
        lua_pushnumber(L, v[1]);
        lua_seti(L, _v_index, 2);
        lua_pushnumber(L, v[2]);
        lua_seti(L, _v_index, 3);
        lua_pushnumber(L, v[3]);
        lua_seti(L, _v_index, 4);
    };
    return 1;
}

static int DragFloat4Ex(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _v_index = 2;
    float v[] = {
        (float)field_tonumber(L, 2, 1),
        (float)field_tonumber(L, 2, 2),
        (float)field_tonumber(L, 2, 3),
        (float)field_tonumber(L, 2, 4),
    };
    auto v_speed = (float)luaL_optnumber(L, 3, 1.0f);
    auto v_min = (float)luaL_optnumber(L, 4, 0.0f);
    auto v_max = (float)luaL_optnumber(L, 5, 0.0f);
    auto format = luaL_optstring(L, 6, "%.3f");
    auto flags = (ImGuiSliderFlags)luaL_optinteger(L, 7, lua_Integer(ImGuiSliderFlags_None));
    auto _retval = ImGui::DragFloat4(label, v, v_speed, v_min, v_max, format, flags);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushnumber(L, v[0]);
        lua_seti(L, _v_index, 1);
        lua_pushnumber(L, v[1]);
        lua_seti(L, _v_index, 2);
        lua_pushnumber(L, v[2]);
        lua_seti(L, _v_index, 3);
        lua_pushnumber(L, v[3]);
        lua_seti(L, _v_index, 4);
    };
    return 1;
}

static int DragFloatRange2(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _v_current_min_index = 2;
    float v_current_min[] = {
        (float)field_tonumber(L, 2, 1),
    };
    luaL_checktype(L, 3, LUA_TTABLE);
    int _v_current_max_index = 3;
    float v_current_max[] = {
        (float)field_tonumber(L, 3, 1),
    };
    auto _retval = ImGui::DragFloatRange2(label, v_current_min, v_current_max);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushnumber(L, v_current_min[0]);
        lua_seti(L, _v_current_min_index, 1);
    };
    if (_retval) {
        lua_pushnumber(L, v_current_max[0]);
        lua_seti(L, _v_current_max_index, 1);
    };
    return 1;
}

static int DragFloatRange2Ex(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _v_current_min_index = 2;
    float v_current_min[] = {
        (float)field_tonumber(L, 2, 1),
    };
    luaL_checktype(L, 3, LUA_TTABLE);
    int _v_current_max_index = 3;
    float v_current_max[] = {
        (float)field_tonumber(L, 3, 1),
    };
    auto v_speed = (float)luaL_optnumber(L, 4, 1.0f);
    auto v_min = (float)luaL_optnumber(L, 5, 0.0f);
    auto v_max = (float)luaL_optnumber(L, 6, 0.0f);
    auto format = luaL_optstring(L, 7, "%.3f");
    auto format_max = luaL_optstring(L, 8, NULL);
    auto flags = (ImGuiSliderFlags)luaL_optinteger(L, 9, lua_Integer(ImGuiSliderFlags_None));
    auto _retval = ImGui::DragFloatRange2(label, v_current_min, v_current_max, v_speed, v_min, v_max, format, format_max, flags);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushnumber(L, v_current_min[0]);
        lua_seti(L, _v_current_min_index, 1);
    };
    if (_retval) {
        lua_pushnumber(L, v_current_max[0]);
        lua_seti(L, _v_current_max_index, 1);
    };
    return 1;
}

static int DragInt(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _v_index = 2;
    int v[] = {
        (int)field_tointeger(L, 2, 1),
    };
    auto _retval = ImGui::DragInt(label, v);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushinteger(L, v[0]);
        lua_seti(L, _v_index, 1);
    };
    return 1;
}

static int DragIntEx(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _v_index = 2;
    int v[] = {
        (int)field_tointeger(L, 2, 1),
    };
    auto v_speed = (float)luaL_optnumber(L, 3, 1.0f);
    auto v_min = (int)luaL_optinteger(L, 4, 0);
    auto v_max = (int)luaL_optinteger(L, 5, 0);
    auto format = luaL_optstring(L, 6, "%d");
    auto flags = (ImGuiSliderFlags)luaL_optinteger(L, 7, lua_Integer(ImGuiSliderFlags_None));
    auto _retval = ImGui::DragInt(label, v, v_speed, v_min, v_max, format, flags);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushinteger(L, v[0]);
        lua_seti(L, _v_index, 1);
    };
    return 1;
}

static int DragInt2(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _v_index = 2;
    int v[] = {
        (int)field_tointeger(L, 2, 1),
        (int)field_tointeger(L, 2, 2),
    };
    auto _retval = ImGui::DragInt2(label, v);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushinteger(L, v[0]);
        lua_seti(L, _v_index, 1);
        lua_pushinteger(L, v[1]);
        lua_seti(L, _v_index, 2);
    };
    return 1;
}

static int DragInt2Ex(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _v_index = 2;
    int v[] = {
        (int)field_tointeger(L, 2, 1),
        (int)field_tointeger(L, 2, 2),
    };
    auto v_speed = (float)luaL_optnumber(L, 3, 1.0f);
    auto v_min = (int)luaL_optinteger(L, 4, 0);
    auto v_max = (int)luaL_optinteger(L, 5, 0);
    auto format = luaL_optstring(L, 6, "%d");
    auto flags = (ImGuiSliderFlags)luaL_optinteger(L, 7, lua_Integer(ImGuiSliderFlags_None));
    auto _retval = ImGui::DragInt2(label, v, v_speed, v_min, v_max, format, flags);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushinteger(L, v[0]);
        lua_seti(L, _v_index, 1);
        lua_pushinteger(L, v[1]);
        lua_seti(L, _v_index, 2);
    };
    return 1;
}

static int DragInt3(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _v_index = 2;
    int v[] = {
        (int)field_tointeger(L, 2, 1),
        (int)field_tointeger(L, 2, 2),
        (int)field_tointeger(L, 2, 3),
    };
    auto _retval = ImGui::DragInt3(label, v);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushinteger(L, v[0]);
        lua_seti(L, _v_index, 1);
        lua_pushinteger(L, v[1]);
        lua_seti(L, _v_index, 2);
        lua_pushinteger(L, v[2]);
        lua_seti(L, _v_index, 3);
    };
    return 1;
}

static int DragInt3Ex(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _v_index = 2;
    int v[] = {
        (int)field_tointeger(L, 2, 1),
        (int)field_tointeger(L, 2, 2),
        (int)field_tointeger(L, 2, 3),
    };
    auto v_speed = (float)luaL_optnumber(L, 3, 1.0f);
    auto v_min = (int)luaL_optinteger(L, 4, 0);
    auto v_max = (int)luaL_optinteger(L, 5, 0);
    auto format = luaL_optstring(L, 6, "%d");
    auto flags = (ImGuiSliderFlags)luaL_optinteger(L, 7, lua_Integer(ImGuiSliderFlags_None));
    auto _retval = ImGui::DragInt3(label, v, v_speed, v_min, v_max, format, flags);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushinteger(L, v[0]);
        lua_seti(L, _v_index, 1);
        lua_pushinteger(L, v[1]);
        lua_seti(L, _v_index, 2);
        lua_pushinteger(L, v[2]);
        lua_seti(L, _v_index, 3);
    };
    return 1;
}

static int DragInt4(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _v_index = 2;
    int v[] = {
        (int)field_tointeger(L, 2, 1),
        (int)field_tointeger(L, 2, 2),
        (int)field_tointeger(L, 2, 3),
        (int)field_tointeger(L, 2, 4),
    };
    auto _retval = ImGui::DragInt4(label, v);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushinteger(L, v[0]);
        lua_seti(L, _v_index, 1);
        lua_pushinteger(L, v[1]);
        lua_seti(L, _v_index, 2);
        lua_pushinteger(L, v[2]);
        lua_seti(L, _v_index, 3);
        lua_pushinteger(L, v[3]);
        lua_seti(L, _v_index, 4);
    };
    return 1;
}

static int DragInt4Ex(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _v_index = 2;
    int v[] = {
        (int)field_tointeger(L, 2, 1),
        (int)field_tointeger(L, 2, 2),
        (int)field_tointeger(L, 2, 3),
        (int)field_tointeger(L, 2, 4),
    };
    auto v_speed = (float)luaL_optnumber(L, 3, 1.0f);
    auto v_min = (int)luaL_optinteger(L, 4, 0);
    auto v_max = (int)luaL_optinteger(L, 5, 0);
    auto format = luaL_optstring(L, 6, "%d");
    auto flags = (ImGuiSliderFlags)luaL_optinteger(L, 7, lua_Integer(ImGuiSliderFlags_None));
    auto _retval = ImGui::DragInt4(label, v, v_speed, v_min, v_max, format, flags);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushinteger(L, v[0]);
        lua_seti(L, _v_index, 1);
        lua_pushinteger(L, v[1]);
        lua_seti(L, _v_index, 2);
        lua_pushinteger(L, v[2]);
        lua_seti(L, _v_index, 3);
        lua_pushinteger(L, v[3]);
        lua_seti(L, _v_index, 4);
    };
    return 1;
}

static int DragIntRange2(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _v_current_min_index = 2;
    int v_current_min[] = {
        (int)field_tointeger(L, 2, 1),
    };
    luaL_checktype(L, 3, LUA_TTABLE);
    int _v_current_max_index = 3;
    int v_current_max[] = {
        (int)field_tointeger(L, 3, 1),
    };
    auto _retval = ImGui::DragIntRange2(label, v_current_min, v_current_max);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushinteger(L, v_current_min[0]);
        lua_seti(L, _v_current_min_index, 1);
    };
    if (_retval) {
        lua_pushinteger(L, v_current_max[0]);
        lua_seti(L, _v_current_max_index, 1);
    };
    return 1;
}

static int DragIntRange2Ex(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _v_current_min_index = 2;
    int v_current_min[] = {
        (int)field_tointeger(L, 2, 1),
    };
    luaL_checktype(L, 3, LUA_TTABLE);
    int _v_current_max_index = 3;
    int v_current_max[] = {
        (int)field_tointeger(L, 3, 1),
    };
    auto v_speed = (float)luaL_optnumber(L, 4, 1.0f);
    auto v_min = (int)luaL_optinteger(L, 5, 0);
    auto v_max = (int)luaL_optinteger(L, 6, 0);
    auto format = luaL_optstring(L, 7, "%d");
    auto format_max = luaL_optstring(L, 8, NULL);
    auto flags = (ImGuiSliderFlags)luaL_optinteger(L, 9, lua_Integer(ImGuiSliderFlags_None));
    auto _retval = ImGui::DragIntRange2(label, v_current_min, v_current_max, v_speed, v_min, v_max, format, format_max, flags);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushinteger(L, v_current_min[0]);
        lua_seti(L, _v_current_min_index, 1);
    };
    if (_retval) {
        lua_pushinteger(L, v_current_max[0]);
        lua_seti(L, _v_current_max_index, 1);
    };
    return 1;
}

static int SliderFloat(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _v_index = 2;
    float v[] = {
        (float)field_tonumber(L, 2, 1),
    };
    auto v_min = (float)luaL_checknumber(L, 3);
    auto v_max = (float)luaL_checknumber(L, 4);
    auto _retval = ImGui::SliderFloat(label, v, v_min, v_max);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushnumber(L, v[0]);
        lua_seti(L, _v_index, 1);
    };
    return 1;
}

static int SliderFloatEx(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _v_index = 2;
    float v[] = {
        (float)field_tonumber(L, 2, 1),
    };
    auto v_min = (float)luaL_checknumber(L, 3);
    auto v_max = (float)luaL_checknumber(L, 4);
    auto format = luaL_optstring(L, 5, "%.3f");
    auto flags = (ImGuiSliderFlags)luaL_optinteger(L, 6, lua_Integer(ImGuiSliderFlags_None));
    auto _retval = ImGui::SliderFloat(label, v, v_min, v_max, format, flags);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushnumber(L, v[0]);
        lua_seti(L, _v_index, 1);
    };
    return 1;
}

static int SliderFloat2(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _v_index = 2;
    float v[] = {
        (float)field_tonumber(L, 2, 1),
        (float)field_tonumber(L, 2, 2),
    };
    auto v_min = (float)luaL_checknumber(L, 3);
    auto v_max = (float)luaL_checknumber(L, 4);
    auto _retval = ImGui::SliderFloat2(label, v, v_min, v_max);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushnumber(L, v[0]);
        lua_seti(L, _v_index, 1);
        lua_pushnumber(L, v[1]);
        lua_seti(L, _v_index, 2);
    };
    return 1;
}

static int SliderFloat2Ex(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _v_index = 2;
    float v[] = {
        (float)field_tonumber(L, 2, 1),
        (float)field_tonumber(L, 2, 2),
    };
    auto v_min = (float)luaL_checknumber(L, 3);
    auto v_max = (float)luaL_checknumber(L, 4);
    auto format = luaL_optstring(L, 5, "%.3f");
    auto flags = (ImGuiSliderFlags)luaL_optinteger(L, 6, lua_Integer(ImGuiSliderFlags_None));
    auto _retval = ImGui::SliderFloat2(label, v, v_min, v_max, format, flags);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushnumber(L, v[0]);
        lua_seti(L, _v_index, 1);
        lua_pushnumber(L, v[1]);
        lua_seti(L, _v_index, 2);
    };
    return 1;
}

static int SliderFloat3(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _v_index = 2;
    float v[] = {
        (float)field_tonumber(L, 2, 1),
        (float)field_tonumber(L, 2, 2),
        (float)field_tonumber(L, 2, 3),
    };
    auto v_min = (float)luaL_checknumber(L, 3);
    auto v_max = (float)luaL_checknumber(L, 4);
    auto _retval = ImGui::SliderFloat3(label, v, v_min, v_max);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushnumber(L, v[0]);
        lua_seti(L, _v_index, 1);
        lua_pushnumber(L, v[1]);
        lua_seti(L, _v_index, 2);
        lua_pushnumber(L, v[2]);
        lua_seti(L, _v_index, 3);
    };
    return 1;
}

static int SliderFloat3Ex(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _v_index = 2;
    float v[] = {
        (float)field_tonumber(L, 2, 1),
        (float)field_tonumber(L, 2, 2),
        (float)field_tonumber(L, 2, 3),
    };
    auto v_min = (float)luaL_checknumber(L, 3);
    auto v_max = (float)luaL_checknumber(L, 4);
    auto format = luaL_optstring(L, 5, "%.3f");
    auto flags = (ImGuiSliderFlags)luaL_optinteger(L, 6, lua_Integer(ImGuiSliderFlags_None));
    auto _retval = ImGui::SliderFloat3(label, v, v_min, v_max, format, flags);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushnumber(L, v[0]);
        lua_seti(L, _v_index, 1);
        lua_pushnumber(L, v[1]);
        lua_seti(L, _v_index, 2);
        lua_pushnumber(L, v[2]);
        lua_seti(L, _v_index, 3);
    };
    return 1;
}

static int SliderFloat4(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _v_index = 2;
    float v[] = {
        (float)field_tonumber(L, 2, 1),
        (float)field_tonumber(L, 2, 2),
        (float)field_tonumber(L, 2, 3),
        (float)field_tonumber(L, 2, 4),
    };
    auto v_min = (float)luaL_checknumber(L, 3);
    auto v_max = (float)luaL_checknumber(L, 4);
    auto _retval = ImGui::SliderFloat4(label, v, v_min, v_max);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushnumber(L, v[0]);
        lua_seti(L, _v_index, 1);
        lua_pushnumber(L, v[1]);
        lua_seti(L, _v_index, 2);
        lua_pushnumber(L, v[2]);
        lua_seti(L, _v_index, 3);
        lua_pushnumber(L, v[3]);
        lua_seti(L, _v_index, 4);
    };
    return 1;
}

static int SliderFloat4Ex(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _v_index = 2;
    float v[] = {
        (float)field_tonumber(L, 2, 1),
        (float)field_tonumber(L, 2, 2),
        (float)field_tonumber(L, 2, 3),
        (float)field_tonumber(L, 2, 4),
    };
    auto v_min = (float)luaL_checknumber(L, 3);
    auto v_max = (float)luaL_checknumber(L, 4);
    auto format = luaL_optstring(L, 5, "%.3f");
    auto flags = (ImGuiSliderFlags)luaL_optinteger(L, 6, lua_Integer(ImGuiSliderFlags_None));
    auto _retval = ImGui::SliderFloat4(label, v, v_min, v_max, format, flags);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushnumber(L, v[0]);
        lua_seti(L, _v_index, 1);
        lua_pushnumber(L, v[1]);
        lua_seti(L, _v_index, 2);
        lua_pushnumber(L, v[2]);
        lua_seti(L, _v_index, 3);
        lua_pushnumber(L, v[3]);
        lua_seti(L, _v_index, 4);
    };
    return 1;
}

static int SliderAngle(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _v_rad_index = 2;
    float v_rad[] = {
        (float)field_tonumber(L, 2, 1),
    };
    auto _retval = ImGui::SliderAngle(label, v_rad);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushnumber(L, v_rad[0]);
        lua_seti(L, _v_rad_index, 1);
    };
    return 1;
}

static int SliderAngleEx(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _v_rad_index = 2;
    float v_rad[] = {
        (float)field_tonumber(L, 2, 1),
    };
    auto v_degrees_min = (float)luaL_optnumber(L, 3, -360.0f);
    auto v_degrees_max = (float)luaL_optnumber(L, 4, +360.0f);
    auto format = luaL_optstring(L, 5, "%.0f deg");
    auto flags = (ImGuiSliderFlags)luaL_optinteger(L, 6, lua_Integer(ImGuiSliderFlags_None));
    auto _retval = ImGui::SliderAngle(label, v_rad, v_degrees_min, v_degrees_max, format, flags);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushnumber(L, v_rad[0]);
        lua_seti(L, _v_rad_index, 1);
    };
    return 1;
}

static int SliderInt(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _v_index = 2;
    int v[] = {
        (int)field_tointeger(L, 2, 1),
    };
    auto v_min = (int)luaL_checkinteger(L, 3);
    auto v_max = (int)luaL_checkinteger(L, 4);
    auto _retval = ImGui::SliderInt(label, v, v_min, v_max);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushinteger(L, v[0]);
        lua_seti(L, _v_index, 1);
    };
    return 1;
}

static int SliderIntEx(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _v_index = 2;
    int v[] = {
        (int)field_tointeger(L, 2, 1),
    };
    auto v_min = (int)luaL_checkinteger(L, 3);
    auto v_max = (int)luaL_checkinteger(L, 4);
    auto format = luaL_optstring(L, 5, "%d");
    auto flags = (ImGuiSliderFlags)luaL_optinteger(L, 6, lua_Integer(ImGuiSliderFlags_None));
    auto _retval = ImGui::SliderInt(label, v, v_min, v_max, format, flags);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushinteger(L, v[0]);
        lua_seti(L, _v_index, 1);
    };
    return 1;
}

static int SliderInt2(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _v_index = 2;
    int v[] = {
        (int)field_tointeger(L, 2, 1),
        (int)field_tointeger(L, 2, 2),
    };
    auto v_min = (int)luaL_checkinteger(L, 3);
    auto v_max = (int)luaL_checkinteger(L, 4);
    auto _retval = ImGui::SliderInt2(label, v, v_min, v_max);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushinteger(L, v[0]);
        lua_seti(L, _v_index, 1);
        lua_pushinteger(L, v[1]);
        lua_seti(L, _v_index, 2);
    };
    return 1;
}

static int SliderInt2Ex(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _v_index = 2;
    int v[] = {
        (int)field_tointeger(L, 2, 1),
        (int)field_tointeger(L, 2, 2),
    };
    auto v_min = (int)luaL_checkinteger(L, 3);
    auto v_max = (int)luaL_checkinteger(L, 4);
    auto format = luaL_optstring(L, 5, "%d");
    auto flags = (ImGuiSliderFlags)luaL_optinteger(L, 6, lua_Integer(ImGuiSliderFlags_None));
    auto _retval = ImGui::SliderInt2(label, v, v_min, v_max, format, flags);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushinteger(L, v[0]);
        lua_seti(L, _v_index, 1);
        lua_pushinteger(L, v[1]);
        lua_seti(L, _v_index, 2);
    };
    return 1;
}

static int SliderInt3(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _v_index = 2;
    int v[] = {
        (int)field_tointeger(L, 2, 1),
        (int)field_tointeger(L, 2, 2),
        (int)field_tointeger(L, 2, 3),
    };
    auto v_min = (int)luaL_checkinteger(L, 3);
    auto v_max = (int)luaL_checkinteger(L, 4);
    auto _retval = ImGui::SliderInt3(label, v, v_min, v_max);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushinteger(L, v[0]);
        lua_seti(L, _v_index, 1);
        lua_pushinteger(L, v[1]);
        lua_seti(L, _v_index, 2);
        lua_pushinteger(L, v[2]);
        lua_seti(L, _v_index, 3);
    };
    return 1;
}

static int SliderInt3Ex(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _v_index = 2;
    int v[] = {
        (int)field_tointeger(L, 2, 1),
        (int)field_tointeger(L, 2, 2),
        (int)field_tointeger(L, 2, 3),
    };
    auto v_min = (int)luaL_checkinteger(L, 3);
    auto v_max = (int)luaL_checkinteger(L, 4);
    auto format = luaL_optstring(L, 5, "%d");
    auto flags = (ImGuiSliderFlags)luaL_optinteger(L, 6, lua_Integer(ImGuiSliderFlags_None));
    auto _retval = ImGui::SliderInt3(label, v, v_min, v_max, format, flags);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushinteger(L, v[0]);
        lua_seti(L, _v_index, 1);
        lua_pushinteger(L, v[1]);
        lua_seti(L, _v_index, 2);
        lua_pushinteger(L, v[2]);
        lua_seti(L, _v_index, 3);
    };
    return 1;
}

static int SliderInt4(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _v_index = 2;
    int v[] = {
        (int)field_tointeger(L, 2, 1),
        (int)field_tointeger(L, 2, 2),
        (int)field_tointeger(L, 2, 3),
        (int)field_tointeger(L, 2, 4),
    };
    auto v_min = (int)luaL_checkinteger(L, 3);
    auto v_max = (int)luaL_checkinteger(L, 4);
    auto _retval = ImGui::SliderInt4(label, v, v_min, v_max);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushinteger(L, v[0]);
        lua_seti(L, _v_index, 1);
        lua_pushinteger(L, v[1]);
        lua_seti(L, _v_index, 2);
        lua_pushinteger(L, v[2]);
        lua_seti(L, _v_index, 3);
        lua_pushinteger(L, v[3]);
        lua_seti(L, _v_index, 4);
    };
    return 1;
}

static int SliderInt4Ex(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _v_index = 2;
    int v[] = {
        (int)field_tointeger(L, 2, 1),
        (int)field_tointeger(L, 2, 2),
        (int)field_tointeger(L, 2, 3),
        (int)field_tointeger(L, 2, 4),
    };
    auto v_min = (int)luaL_checkinteger(L, 3);
    auto v_max = (int)luaL_checkinteger(L, 4);
    auto format = luaL_optstring(L, 5, "%d");
    auto flags = (ImGuiSliderFlags)luaL_optinteger(L, 6, lua_Integer(ImGuiSliderFlags_None));
    auto _retval = ImGui::SliderInt4(label, v, v_min, v_max, format, flags);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushinteger(L, v[0]);
        lua_seti(L, _v_index, 1);
        lua_pushinteger(L, v[1]);
        lua_seti(L, _v_index, 2);
        lua_pushinteger(L, v[2]);
        lua_seti(L, _v_index, 3);
        lua_pushinteger(L, v[3]);
        lua_seti(L, _v_index, 4);
    };
    return 1;
}

static int VSliderFloat(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    auto size = ImVec2 {
        (float)luaL_checknumber(L, 2),
        (float)luaL_checknumber(L, 3),
    };
    luaL_checktype(L, 4, LUA_TTABLE);
    int _v_index = 4;
    float v[] = {
        (float)field_tonumber(L, 4, 1),
    };
    auto v_min = (float)luaL_checknumber(L, 5);
    auto v_max = (float)luaL_checknumber(L, 6);
    auto _retval = ImGui::VSliderFloat(label, size, v, v_min, v_max);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushnumber(L, v[0]);
        lua_seti(L, _v_index, 1);
    };
    return 1;
}

static int VSliderFloatEx(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    auto size = ImVec2 {
        (float)luaL_checknumber(L, 2),
        (float)luaL_checknumber(L, 3),
    };
    luaL_checktype(L, 4, LUA_TTABLE);
    int _v_index = 4;
    float v[] = {
        (float)field_tonumber(L, 4, 1),
    };
    auto v_min = (float)luaL_checknumber(L, 5);
    auto v_max = (float)luaL_checknumber(L, 6);
    auto format = luaL_optstring(L, 7, "%.3f");
    auto flags = (ImGuiSliderFlags)luaL_optinteger(L, 8, lua_Integer(ImGuiSliderFlags_None));
    auto _retval = ImGui::VSliderFloat(label, size, v, v_min, v_max, format, flags);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushnumber(L, v[0]);
        lua_seti(L, _v_index, 1);
    };
    return 1;
}

static int VSliderInt(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    auto size = ImVec2 {
        (float)luaL_checknumber(L, 2),
        (float)luaL_checknumber(L, 3),
    };
    luaL_checktype(L, 4, LUA_TTABLE);
    int _v_index = 4;
    int v[] = {
        (int)field_tointeger(L, 4, 1),
    };
    auto v_min = (int)luaL_checkinteger(L, 5);
    auto v_max = (int)luaL_checkinteger(L, 6);
    auto _retval = ImGui::VSliderInt(label, size, v, v_min, v_max);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushinteger(L, v[0]);
        lua_seti(L, _v_index, 1);
    };
    return 1;
}

static int VSliderIntEx(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    auto size = ImVec2 {
        (float)luaL_checknumber(L, 2),
        (float)luaL_checknumber(L, 3),
    };
    luaL_checktype(L, 4, LUA_TTABLE);
    int _v_index = 4;
    int v[] = {
        (int)field_tointeger(L, 4, 1),
    };
    auto v_min = (int)luaL_checkinteger(L, 5);
    auto v_max = (int)luaL_checkinteger(L, 6);
    auto format = luaL_optstring(L, 7, "%d");
    auto flags = (ImGuiSliderFlags)luaL_optinteger(L, 8, lua_Integer(ImGuiSliderFlags_None));
    auto _retval = ImGui::VSliderInt(label, size, v, v_min, v_max, format, flags);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushinteger(L, v[0]);
        lua_seti(L, _v_index, 1);
    };
    return 1;
}

static int ColorEdit3(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _col_index = 2;
    float col[] = {
        (float)field_tonumber(L, 2, 1),
        (float)field_tonumber(L, 2, 2),
        (float)field_tonumber(L, 2, 3),
    };
    auto flags = (ImGuiColorEditFlags)luaL_optinteger(L, 3, lua_Integer(ImGuiColorEditFlags_None));
    auto _retval = ImGui::ColorEdit3(label, col, flags);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushnumber(L, col[0]);
        lua_seti(L, _col_index, 1);
        lua_pushnumber(L, col[1]);
        lua_seti(L, _col_index, 2);
        lua_pushnumber(L, col[2]);
        lua_seti(L, _col_index, 3);
    };
    return 1;
}

static int ColorEdit4(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _col_index = 2;
    float col[] = {
        (float)field_tonumber(L, 2, 1),
        (float)field_tonumber(L, 2, 2),
        (float)field_tonumber(L, 2, 3),
        (float)field_tonumber(L, 2, 4),
    };
    auto flags = (ImGuiColorEditFlags)luaL_optinteger(L, 3, lua_Integer(ImGuiColorEditFlags_None));
    auto _retval = ImGui::ColorEdit4(label, col, flags);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushnumber(L, col[0]);
        lua_seti(L, _col_index, 1);
        lua_pushnumber(L, col[1]);
        lua_seti(L, _col_index, 2);
        lua_pushnumber(L, col[2]);
        lua_seti(L, _col_index, 3);
        lua_pushnumber(L, col[3]);
        lua_seti(L, _col_index, 4);
    };
    return 1;
}

static int ColorPicker3(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _col_index = 2;
    float col[] = {
        (float)field_tonumber(L, 2, 1),
        (float)field_tonumber(L, 2, 2),
        (float)field_tonumber(L, 2, 3),
    };
    auto flags = (ImGuiColorEditFlags)luaL_optinteger(L, 3, lua_Integer(ImGuiColorEditFlags_None));
    auto _retval = ImGui::ColorPicker3(label, col, flags);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushnumber(L, col[0]);
        lua_seti(L, _col_index, 1);
        lua_pushnumber(L, col[1]);
        lua_seti(L, _col_index, 2);
        lua_pushnumber(L, col[2]);
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
        (float)luaL_optnumber(L, 7, 0),
        (float)luaL_optnumber(L, 8, 0),
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
    luaL_checktype(L, 2, LUA_TTABLE);
    int _p_visible_index = 2;
    bool p_visible[] = {
        field_toboolean(L, 2, 1),
    };
    auto flags = (ImGuiTreeNodeFlags)luaL_optinteger(L, 3, lua_Integer(ImGuiTreeNodeFlags_None));
    auto _retval = ImGui::CollapsingHeader(label, p_visible, flags);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushboolean(L, p_visible[0]);
        lua_seti(L, _p_visible_index, 1);
    };
    return 1;
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
        (float)luaL_optnumber(L, 4, 0),
        (float)luaL_optnumber(L, 5, 0),
    };
    auto _retval = ImGui::Selectable(label, selected, flags, size);
    lua_pushboolean(L, _retval);
    return 1;
}

static int SelectableBoolPtr(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _p_selected_index = 2;
    bool p_selected[] = {
        field_toboolean(L, 2, 1),
    };
    auto flags = (ImGuiSelectableFlags)luaL_optinteger(L, 3, lua_Integer(ImGuiSelectableFlags_None));
    auto _retval = ImGui::Selectable(label, p_selected, flags);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushboolean(L, p_selected[0]);
        lua_seti(L, _p_selected_index, 1);
    };
    return 1;
}

static int SelectableBoolPtrEx(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int _p_selected_index = 2;
    bool p_selected[] = {
        field_toboolean(L, 2, 1),
    };
    auto flags = (ImGuiSelectableFlags)luaL_optinteger(L, 3, lua_Integer(ImGuiSelectableFlags_None));
    auto size = ImVec2 {
        (float)luaL_optnumber(L, 4, 0),
        (float)luaL_optnumber(L, 5, 0),
    };
    auto _retval = ImGui::Selectable(label, p_selected, flags, size);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushboolean(L, p_selected[0]);
        lua_seti(L, _p_selected_index, 1);
    };
    return 1;
}

static int BeginListBox(lua_State* L) {
    auto label = luaL_checkstring(L, 1);
    auto size = ImVec2 {
        (float)luaL_optnumber(L, 2, 0),
        (float)luaL_optnumber(L, 3, 0),
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
    luaL_checktype(L, 3, LUA_TTABLE);
    int _p_selected_index = 3;
    bool p_selected[] = {
        field_toboolean(L, 3, 1),
    };
    auto enabled = lua_isnoneornil(L, 4)? true: !!lua_toboolean(L, 4);
    auto _retval = ImGui::MenuItem(label, shortcut, p_selected, enabled);
    lua_pushboolean(L, _retval);
    if (_retval) {
        lua_pushboolean(L, p_selected[0]);
        lua_seti(L, _p_selected_index, 1);
    };
    return 1;
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
        (float)luaL_optnumber(L, 4, 0.0f),
        (float)luaL_optnumber(L, 5, 0.0f),
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
        { "Begin", Begin },
        { "End", End },
        { "BeginChild", BeginChild },
        { "BeginChildID", BeginChildID },
        { "EndChild", EndChild },
        { "IsWindowAppearing", IsWindowAppearing },
        { "IsWindowCollapsed", IsWindowCollapsed },
        { "IsWindowFocused", IsWindowFocused },
        { "IsWindowHovered", IsWindowHovered },
        { "GetWindowDpiScale", GetWindowDpiScale },
        { "GetWindowPos", GetWindowPos },
        { "GetWindowSize", GetWindowSize },
        { "GetWindowWidth", GetWindowWidth },
        { "GetWindowHeight", GetWindowHeight },
        { "SetNextWindowPos", SetNextWindowPos },
        { "SetNextWindowPosEx", SetNextWindowPosEx },
        { "SetNextWindowSize", SetNextWindowSize },
        { "SetNextWindowContentSize", SetNextWindowContentSize },
        { "SetNextWindowCollapsed", SetNextWindowCollapsed },
        { "SetNextWindowFocus", SetNextWindowFocus },
        { "SetNextWindowScroll", SetNextWindowScroll },
        { "SetNextWindowBgAlpha", SetNextWindowBgAlpha },
        { "SetNextWindowViewport", SetNextWindowViewport },
        { "SetWindowPos", SetWindowPos },
        { "SetWindowSize", SetWindowSize },
        { "SetWindowCollapsed", SetWindowCollapsed },
        { "SetWindowFocus", SetWindowFocus },
        { "SetWindowFontScale", SetWindowFontScale },
        { "SetWindowPosStr", SetWindowPosStr },
        { "SetWindowSizeStr", SetWindowSizeStr },
        { "SetWindowCollapsedStr", SetWindowCollapsedStr },
        { "SetWindowFocusStr", SetWindowFocusStr },
        { "GetContentRegionAvail", GetContentRegionAvail },
        { "GetContentRegionMax", GetContentRegionMax },
        { "GetWindowContentRegionMin", GetWindowContentRegionMin },
        { "GetWindowContentRegionMax", GetWindowContentRegionMax },
        { "GetScrollX", GetScrollX },
        { "GetScrollY", GetScrollY },
        { "SetScrollX", SetScrollX },
        { "SetScrollY", SetScrollY },
        { "GetScrollMaxX", GetScrollMaxX },
        { "GetScrollMaxY", GetScrollMaxY },
        { "SetScrollHereX", SetScrollHereX },
        { "SetScrollHereY", SetScrollHereY },
        { "SetScrollFromPosX", SetScrollFromPosX },
        { "SetScrollFromPosY", SetScrollFromPosY },
        { "PopFont", PopFont },
        { "PushStyleColor", PushStyleColor },
        { "PushStyleColorImVec4", PushStyleColorImVec4 },
        { "PopStyleColor", PopStyleColor },
        { "PopStyleColorEx", PopStyleColorEx },
        { "PushStyleVar", PushStyleVar },
        { "PushStyleVarImVec2", PushStyleVarImVec2 },
        { "PopStyleVar", PopStyleVar },
        { "PopStyleVarEx", PopStyleVarEx },
        { "PushTabStop", PushTabStop },
        { "PopTabStop", PopTabStop },
        { "PushButtonRepeat", PushButtonRepeat },
        { "PopButtonRepeat", PopButtonRepeat },
        { "PushItemWidth", PushItemWidth },
        { "PopItemWidth", PopItemWidth },
        { "SetNextItemWidth", SetNextItemWidth },
        { "CalcItemWidth", CalcItemWidth },
        { "PushTextWrapPos", PushTextWrapPos },
        { "PopTextWrapPos", PopTextWrapPos },
        { "GetFontSize", GetFontSize },
        { "GetFontTexUvWhitePixel", GetFontTexUvWhitePixel },
        { "GetColorU32", GetColorU32 },
        { "GetColorU32Ex", GetColorU32Ex },
        { "GetColorU32ImVec4", GetColorU32ImVec4 },
        { "GetColorU32ImU32", GetColorU32ImU32 },
        { "GetCursorScreenPos", GetCursorScreenPos },
        { "SetCursorScreenPos", SetCursorScreenPos },
        { "GetCursorPos", GetCursorPos },
        { "GetCursorPosX", GetCursorPosX },
        { "GetCursorPosY", GetCursorPosY },
        { "SetCursorPos", SetCursorPos },
        { "SetCursorPosX", SetCursorPosX },
        { "SetCursorPosY", SetCursorPosY },
        { "GetCursorStartPos", GetCursorStartPos },
        { "Separator", Separator },
        { "SameLine", SameLine },
        { "SameLineEx", SameLineEx },
        { "NewLine", NewLine },
        { "Spacing", Spacing },
        { "Dummy", Dummy },
        { "Indent", Indent },
        { "IndentEx", IndentEx },
        { "Unindent", Unindent },
        { "UnindentEx", UnindentEx },
        { "BeginGroup", BeginGroup },
        { "EndGroup", EndGroup },
        { "AlignTextToFramePadding", AlignTextToFramePadding },
        { "GetTextLineHeight", GetTextLineHeight },
        { "GetTextLineHeightWithSpacing", GetTextLineHeightWithSpacing },
        { "GetFrameHeight", GetFrameHeight },
        { "GetFrameHeightWithSpacing", GetFrameHeightWithSpacing },
        { "PushID", PushID },
        { "PushIDStr", PushIDStr },
        { "PushIDPtr", PushIDPtr },
        { "PushIDInt", PushIDInt },
        { "PopID", PopID },
        { "GetID", GetID },
        { "GetIDStr", GetIDStr },
        { "GetIDPtr", GetIDPtr },
        { "Text", Text },
        { "TextColored", TextColored },
        { "TextDisabled", TextDisabled },
        { "TextWrapped", TextWrapped },
        { "LabelText", LabelText },
        { "BulletText", BulletText },
        { "SeparatorText", SeparatorText },
        { "Button", Button },
        { "ButtonEx", ButtonEx },
        { "SmallButton", SmallButton },
        { "InvisibleButton", InvisibleButton },
        { "ArrowButton", ArrowButton },
        { "Checkbox", Checkbox },
        { "CheckboxFlagsIntPtr", CheckboxFlagsIntPtr },
        { "RadioButton", RadioButton },
        { "RadioButtonIntPtr", RadioButtonIntPtr },
        { "ProgressBar", ProgressBar },
        { "Bullet", Bullet },
        { "BeginCombo", BeginCombo },
        { "EndCombo", EndCombo },
        { "Combo", Combo },
        { "ComboEx", ComboEx },
        { "DragFloat", DragFloat },
        { "DragFloatEx", DragFloatEx },
        { "DragFloat2", DragFloat2 },
        { "DragFloat2Ex", DragFloat2Ex },
        { "DragFloat3", DragFloat3 },
        { "DragFloat3Ex", DragFloat3Ex },
        { "DragFloat4", DragFloat4 },
        { "DragFloat4Ex", DragFloat4Ex },
        { "DragFloatRange2", DragFloatRange2 },
        { "DragFloatRange2Ex", DragFloatRange2Ex },
        { "DragInt", DragInt },
        { "DragIntEx", DragIntEx },
        { "DragInt2", DragInt2 },
        { "DragInt2Ex", DragInt2Ex },
        { "DragInt3", DragInt3 },
        { "DragInt3Ex", DragInt3Ex },
        { "DragInt4", DragInt4 },
        { "DragInt4Ex", DragInt4Ex },
        { "DragIntRange2", DragIntRange2 },
        { "DragIntRange2Ex", DragIntRange2Ex },
        { "SliderFloat", SliderFloat },
        { "SliderFloatEx", SliderFloatEx },
        { "SliderFloat2", SliderFloat2 },
        { "SliderFloat2Ex", SliderFloat2Ex },
        { "SliderFloat3", SliderFloat3 },
        { "SliderFloat3Ex", SliderFloat3Ex },
        { "SliderFloat4", SliderFloat4 },
        { "SliderFloat4Ex", SliderFloat4Ex },
        { "SliderAngle", SliderAngle },
        { "SliderAngleEx", SliderAngleEx },
        { "SliderInt", SliderInt },
        { "SliderIntEx", SliderIntEx },
        { "SliderInt2", SliderInt2 },
        { "SliderInt2Ex", SliderInt2Ex },
        { "SliderInt3", SliderInt3 },
        { "SliderInt3Ex", SliderInt3Ex },
        { "SliderInt4", SliderInt4 },
        { "SliderInt4Ex", SliderInt4Ex },
        { "VSliderFloat", VSliderFloat },
        { "VSliderFloatEx", VSliderFloatEx },
        { "VSliderInt", VSliderInt },
        { "VSliderIntEx", VSliderIntEx },
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
