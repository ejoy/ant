#include <imgui.h>
#include <lua.hpp>
#include <new>

namespace imgui::table {

static int BeginTable(lua_State* L) {
	const char* strid = luaL_checkstring(L, 1);
	int columns = (int)luaL_checkinteger(L, 2);
	ImGuiTableFlags flags = (ImGuiTableFlags)luaL_optinteger(L, 3, ImGuiTableFlags_None);
	float outer_width = (float)luaL_optnumber(L, 4, 0.f);
	float outer_height = (float)luaL_optnumber(L, 5, 0.f);
	float inner_width = (float)luaL_optnumber(L, 6, 0.f);
	bool ok = ImGui::BeginTable(strid, columns, flags, ImVec2(outer_width, outer_height), inner_width);
	lua_pushboolean(L, ok);
	return 1;
}

static int EndTable(lua_State* L) {
	ImGui::EndTable();
	return 0;
}

static int TableNextRow(lua_State* L) {
	ImGuiTableRowFlags flags = (ImGuiTableRowFlags)luaL_optinteger(L, 1, ImGuiTableRowFlags_None);
	float min_height = (float)luaL_optnumber(L, 2, 0.f);
	ImGui::TableNextRow(flags, min_height);
	return 0;
}

static int TableNextColumn(lua_State* L) {
	bool ok = ImGui::TableNextColumn();
	lua_pushboolean(L, ok);
	return 1;
}

static int TableSetColumnIndex(lua_State* L) {
	int n = (int)luaL_checkinteger(L, 1);
	bool ok = ImGui::TableSetColumnIndex(n);
	lua_pushboolean(L, ok);
	return 1;
}

static int TableGetColumnIndex(lua_State* L) {
	int n = ImGui::TableGetColumnIndex();
	lua_pushinteger(L, n);
	return 1;
}

static int TableGetRowIndex(lua_State* L) {
	int n = ImGui::TableGetRowIndex();
	lua_pushinteger(L, n);
	return 1;
}

static int TableSetupColumn(lua_State* L) {
	const char* label = luaL_checkstring(L, 1);
	ImGuiTableColumnFlags flags = (ImGuiTableColumnFlags)luaL_optinteger(L, 2, ImGuiTableColumnFlags_None);
	float init_width_or_weight = (float)luaL_optnumber(L, 3, 0.f);
	ImU32 user_id = (ImU32)luaL_optinteger(L, 4, 0);
	ImGui::TableSetupColumn(label, flags, init_width_or_weight, user_id);
	return 0;
}

static int TableSetupScrollFreeze(lua_State* L) {
	int cols = (int)luaL_checkinteger(L, 1);
	int rows = (int)luaL_checkinteger(L, 2);
	ImGui::TableSetupScrollFreeze(cols, rows);
	return 0;
}

static int TableHeadersRow(lua_State* L) {
	ImGui::TableHeadersRow();
	return 0;
}

static int TableHeader(lua_State* L) {
	const char* label = luaL_checkstring(L, 1);
	ImGui::TableHeader(label);
	return 0;
}

static int TableGetColumnCount(lua_State* L) {
	int n = ImGui::TableGetColumnCount();
	lua_pushinteger(L, n);
	return 1;
}

static int TableGetColumnName(lua_State* L) {
	int column = (int)luaL_optinteger(L, 1, -1);
	const char* name = ImGui::TableGetColumnName(column);
	lua_pushstring(L, name);
	return 1;
}

static int TableGetColumnFlags(lua_State* L) {
	int column = (int)luaL_optinteger(L, 1, -1);
	ImGuiTableColumnFlags flags = ImGui::TableGetColumnFlags(column);
	lua_pushinteger(L, flags);
	return 1;
}

static int TableSetColumnEnabled(lua_State* L) {
	int column = (int)luaL_checkinteger(L, 1);
	bool v = lua_toboolean(L, 2);
	ImGui::TableSetColumnEnabled(column, v);
	return 0;
}

static int TableGetSortSpecs(lua_State* L) {
	ImGuiTableSortSpecs* specs = ImGui::TableGetSortSpecs();
	if (!specs->SpecsDirty) {
		lua_pushboolean(L, 0);
		return 1;
	}
	luaL_checktype(L, 1, LUA_TTABLE);
	for (int n = 0; n < specs->SpecsCount; ++n) {
		auto spec = specs->Specs[n];
		if (LUA_TTABLE != lua_geti(L, 1, (lua_Integer)n + 1)) {
			lua_pop(L, 1);
			lua_createtable(L, 0, 4);
			lua_pushvalue(L, -1);
			lua_seti(L, 1, (lua_Integer)n + 1);
		}
		lua_pushinteger(L, spec.ColumnUserID);
		lua_setfield(L, -2, "ColumnUserID");
		lua_pushinteger(L, spec.ColumnIndex);
		lua_setfield(L, -2, "ColumnIndex");
		lua_pushinteger(L, spec.SortOrder);
		lua_setfield(L, -2, "SortOrder");
		lua_pushinteger(L, spec.SortDirection);
		lua_setfield(L, -2, "SortDirection");
	}
	lua_pushinteger(L, (lua_Integer)specs->SpecsCount);
	lua_setfield(L, 1, "n");
	specs->SpecsDirty = false;
	lua_pushboolean(L, 1);
	return 1;
}

static int TableSetBgColor(lua_State* L) {
	ImGuiTableBgTarget target = (ImGuiTableBgTarget)luaL_checkinteger(L, 1);
	ImU32 color = (ImU32)luaL_checkinteger(L, 2);
	int column = (int)luaL_optinteger(L, 3, -1);
	ImGui::TableSetBgColor(target, color, column);
	return 0;
}

void init(lua_State* L) {
	luaL_Reg table[] = {
		{ "BeginTable", BeginTable },
		{ "EndTable", EndTable },
		{ "TableNextRow", TableNextRow },
		{ "TableNextColumn", TableNextColumn },
		{ "TableSetColumnIndex", TableSetColumnIndex },
		{ "TableGetColumnIndex", TableGetColumnIndex },
		{ "TableGetRowIndex", TableGetRowIndex },
		{ "TableSetupColumn", TableSetupColumn },
		{ "TableSetupScrollFreeze", TableSetupScrollFreeze },
		{ "TableHeadersRow", TableHeadersRow },
		{ "TableHeader", TableHeader },
		{ "TableGetColumnCount", TableGetColumnCount },
		{ "TableGetColumnName", TableGetColumnName },
		{ "TableGetColumnFlags", TableGetColumnFlags },
		{ "TableSetColumnEnabled", TableSetColumnEnabled },
		{ "TableGetSortSpecs", TableGetSortSpecs },
		{ "TableSetBgColor", TableSetBgColor },
		{ NULL, NULL },
	};
	luaL_setfuncs(L, table, 0);
}

}
