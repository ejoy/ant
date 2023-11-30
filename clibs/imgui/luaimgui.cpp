#define LUA_LIB

extern "C" {
#include <lua.h>
#include <lauxlib.h>
}

#include <imgui.h>
#include <imgui_internal.h>
#include <algorithm>
#include <cstring>
#include <cstdlib>
#include <cstdint>
#include <functional>
#include <map>
#include <string_view>
#include <bx/platform.h>
#include "imgui_renderer.h"
#include "imgui_platform.h"
#include "imgui_window.h"
#include "fastio.h"

namespace imgui::table { void init(lua_State* L); }

static void*
lua_realloc(lua_State *L, void *ptr, size_t osize, size_t nsize) {
	void *ud;
	lua_Alloc allocator = lua_getallocf (L, &ud);
	return allocator(ud, ptr, osize, nsize);
}

#ifdef _MSC_VER
#pragma region IMP_IMGUI
#endif

#define INDEX_ID 1
#define INDEX_ARGS 2

struct lua_args {
	lua_State *L;
	bool err;
};

template <typename Flags>
static Flags lua_getflags(lua_State* L, int idx) {
	return (Flags)luaL_checkinteger(L, idx);
}

template <typename Flags>
static Flags lua_getflags(lua_State* L, int idx, Flags def) {
	return (Flags)luaL_optinteger(L, idx, lua_Integer(def));
}

static int
lDestroy(lua_State *L) {
	if (ImGui::GetCurrentContext()) {
		rendererDestroy();
		platformShutdown();
	}
	ImGui::DestroyContext();
	platformDestroy();
	return 0;
}

static int dSpace(lua_State* L) {
	const char* str_id = luaL_checkstring(L, 1);
	auto flags = lua_getflags<ImGuiDockNodeFlags>(L, 2);
	float w = (float)luaL_optnumber(L, 3, 0);
	float h = (float)luaL_optnumber(L, 4, 0);
	ImGui::DockSpace(ImGui::GetID(str_id), ImVec2(w, h), flags);
	return 0;
}

static int dBuilderGetCentralRect(lua_State * L) {
	const char* str_id = luaL_checkstring(L, 1);
	ImGuiDockNode* central_node = ImGui::DockBuilderGetCentralNode(ImGui::GetID(str_id));
	lua_pushnumber(L, central_node->Pos.x);
	lua_pushnumber(L, central_node->Pos.y);
	lua_pushnumber(L, central_node->Size.x);
	lua_pushnumber(L, central_node->Size.y);
	return 4;
}

static int lGetMainViewport(lua_State* L) {
	ImGuiViewport* viewport = ImGui::GetMainViewport();
	lua_newtable(L);

	lua_pushinteger(L, viewport->ID);
	lua_setfield(L, -2, "ID");

	lua_pushlightuserdata(L, viewport->PlatformHandle);
	lua_setfield(L, -2, "PlatformHandle");

	lua_newtable(L);
	lua_pushnumber(L, viewport->WorkPos.x);
	lua_seti(L, -2, 1);
	lua_pushnumber(L, viewport->WorkPos.y);
	lua_seti(L, -2, 2);
	lua_setfield(L, -2, "WorkPos");

	lua_newtable(L);
	lua_pushnumber(L, viewport->WorkSize.x);
	lua_seti(L, -2, 1);
	lua_pushnumber(L, viewport->WorkSize.y);
	lua_seti(L, -2, 2);
	lua_setfield(L, -2, "WorkSize");

	// main area position
	lua_newtable(L);
	lua_pushnumber(L, viewport->Pos.x);
	lua_seti(L, -2, 1);
	lua_pushnumber(L, viewport->Pos.y);
	lua_seti(L, -2, 2);
	lua_setfield(L, -2, "MainPos");

	// main area size
	lua_newtable(L);
	lua_pushnumber(L, viewport->Size.x);
	lua_seti(L, -2, 1);
	lua_pushnumber(L, viewport->Size.y);
	lua_seti(L, -2, 2);
	lua_setfield(L, -2, "MainSize");

	// main dpi scale
	lua_pushnumber(L, viewport->DpiScale);
	lua_setfield(L, -2, "DpiScale");

	return 1;
}

static int lPairsInputEvents(lua_State* L) {
	int event_n = (int)luaL_checkinteger(L, 2);
	ImGuiContext& g = *ImGui::GetCurrentContext();
	ImGuiIO& io = ImGui::GetIO();
	for (; event_n < g.InputEventsTrail.Size;++event_n) {
		const ImGuiInputEvent* e = &g.InputEventsTrail[event_n];
		switch (e->Type) {
		case ImGuiInputEventType_MousePos: {
			if (io.WantCaptureMouse) {
				break;
			}
			ImVec2 event_pos(e->MousePos.PosX, e->MousePos.PosY);
			if (ImGui::IsMousePosValid(&event_pos))
				event_pos = ImVec2(ImFloor(event_pos.x), ImFloor(event_pos.y));
			lua_pushinteger(L, ++event_n);
			lua_pushstring(L, "MousePos");
			lua_pushnumber(L, event_pos.x);
			lua_pushnumber(L, event_pos.y);
			return 4;
		}
		case ImGuiInputEventType_MouseWheel:
			if (io.WantCaptureMouse) {
				break;
			}
			if (e->MouseWheel.WheelX == 0.0f && e->MouseWheel.WheelY == 0.0f) {
				break;
			}
			lua_pushinteger(L, ++event_n);
			lua_pushstring(L, "MouseWheel");
			lua_pushnumber(L, e->MouseWheel.WheelX);
			lua_pushnumber(L, e->MouseWheel.WheelY);
			return 4;
		case ImGuiInputEventType_MouseButton:
			if (io.WantCaptureMouse) {
				break;
			}
			lua_pushinteger(L, ++event_n);
			lua_pushstring(L, "MouseButton");
			lua_pushinteger(L, e->MouseButton.Button);
			lua_pushinteger(L, e->MouseButton.Down);
			return 4;
		case ImGuiInputEventType_Key:
		{
			if (io.WantCaptureKeyboard) {
				break;
			}
			auto key = e->Key.Key;
			// TODO: fix Ctrl+Space bug, if Ctrl release before Space, there is no ImGuiKey_LeftCtrl event.
			if (key == ImGuiKey_LeftCtrl) {
				break;
			}
			else if (key == ImGuiMod_Ctrl) {
				key = ImGuiKey_LeftCtrl;
			}
			else if (key < ImGuiKey_KeysData_OFFSET || key >= ImGuiKey_KeysData_OFFSET + ImGuiKey_KeysData_SIZE) {
				break;
			}
			lua_pushinteger(L, ++event_n);
			lua_pushstring(L, "Key");
			lua_pushinteger(L, key);
			lua_pushinteger(L, e->Key.Down);
			return 4;
		}
		case ImGuiInputEventType_MouseViewport:
		case ImGuiInputEventType_Text:
		case ImGuiInputEventType_Focus:
		default:
			break;
		}
	}
	return 0;
}

static int lInputEvents(lua_State* L) {
	lua_pushcfunction(L, lPairsInputEvents);
	lua_pushnil(L);
	lua_pushinteger(L, 0);
	return 3;
}

static ImGuiCond
get_cond(lua_State *L, int index) {
	int t = lua_type(L, index);
	switch (t) {
	case LUA_TSTRING: {
		const char *cond = lua_tostring(L, index);
		switch (cond[0]) {
		case 'a':
		case 'A':
			return ImGuiCond_Appearing;
		case 'o':
		case 'O':
			return ImGuiCond_Once;
		case 'f':
		case 'F':
			return ImGuiCond_FirstUseEver;
		default:
			luaL_error(L, "Invalid ImGuiCond %s", cond);
			break;
		}
	}
	case LUA_TNIL:
	case LUA_TNONE:
		return ImGuiCond_Always;
	default:
		luaL_error(L, "Invalid ImGuiCond type %s", lua_typename(L, t));
	}
	return ImGuiCond_Always;
}

#ifdef _MSC_VER
#pragma endregion IMP_IMGUI
#endif

// Widgets bindings
#ifdef _MSC_VER
#pragma region IMP_WIDGET
#endif

bool f = true;

static int
wButton(lua_State *L) {
	const char * text = luaL_checkstring(L, INDEX_ID);
	float w = (float)luaL_optnumber(L, 2, 0);
	float h = (float)luaL_optnumber(L, 3, 0);
	bool click = ImGui::Button(text, ImVec2(w, h));
	lua_pushboolean(L, click);
	return 1;
}

static int
wSmallButton(lua_State *L) {
	const char * text = luaL_checkstring(L, INDEX_ID);
	bool click = ImGui::SmallButton(text);
	lua_pushboolean(L, click);
	return 1;
}

static int
wInvisibleButton(lua_State *L) {
	const char * text = luaL_checkstring(L, INDEX_ID);
	float w = (float)luaL_optnumber(L, 2, 0);
	float h = (float)luaL_optnumber(L, 3, 0);
	bool click = ImGui::InvisibleButton(text, ImVec2(w, h));
	lua_pushboolean(L, click);
	return 1;
}

static int
wArrowButton(lua_State *L) {
	const char * text = luaL_checkstring(L, INDEX_ID);
	const char * dir = luaL_checkstring(L, 2);
	ImGuiDir d;
	switch (dir[0]) {
	case 'l':case 'L':
		d = ImGuiDir_Left;
		break;
	case 'r':case 'R':
		d = ImGuiDir_Right;
		break;
	case 'u':case 'U':
		d = ImGuiDir_Up;
		break;
	case 'd':case 'D':
		d = ImGuiDir_Down;
		break;
	default:
		d = ImGuiDir_None;
		break;
	}

	bool click = ImGui::ArrowButton(text, d);
	lua_pushboolean(L, click);
	return 1;
}

static int
wColorButton(lua_State *L) {
	const char * desc = luaL_checkstring(L, INDEX_ID);
	float c1 = (float)luaL_checknumber(L, 2);
	float c2 = (float)luaL_checknumber(L, 3);
	float c3 = (float)luaL_checknumber(L, 4);
	float c4 = (float)luaL_optnumber(L, 5, 1.0f);
	auto flags = lua_getflags<ImGuiColorEditFlags>(L, 6, ImGuiColorEditFlags_None);
	float w = (float)luaL_optnumber(L, 7, 0);
	float h = (float)luaL_optnumber(L, 8, 0);
	bool click = ImGui::ColorButton(desc, ImVec4(c1, c2, c3, c4), flags, ImVec2(w, h));
	lua_pushboolean(L, click);
	return 1;
}

// Todo:  Image ,  ImageButton, CheckboxFlags, Combo

static int
wCheckbox(lua_State *L) {
	const char * text = luaL_checkstring(L, INDEX_ID);
	if (lua_type(L, INDEX_ARGS) == LUA_TTABLE) {
		lua_geti(L, INDEX_ARGS, 1);
		bool v = lua_toboolean(L, -1);
		lua_pop(L, 1);
		bool change = ImGui::Checkbox(text, &v);
		lua_pushboolean(L, v);
		lua_seti(L, INDEX_ARGS, 1);
		lua_pushboolean(L, change);
		return 1;
	} else {
		bool v = lua_toboolean(L, 2);
		bool change = ImGui::Checkbox(text, &v);
		lua_pushboolean(L, change);
		lua_pushboolean(L, v);
		return 2;
	}
}

static int
wRadioButton(lua_State *L) {
	const char * text = luaL_checkstring(L, INDEX_ID);
	bool v = lua_toboolean(L, 2);
	v = ImGui::RadioButton(text, v);
	lua_pushboolean(L, v);
	return 1;
}

static int
wProgressBar(lua_State *L) {
	float fraction = (float)luaL_checknumber(L, 1);
	float w = -1;
	float h = 0; 
	const char *overlay = NULL;
	if (lua_type(L, 2) == LUA_TSTRING) {
		overlay = lua_tostring(L, 2);
	} else {
		w = (float)luaL_optnumber(L, 2, -1);
		h = (float)luaL_optnumber(L, 3, 0);
		if (lua_isstring(L, 4)) {
			overlay = lua_tostring(L, 4);
		}
	}
	ImGui::ProgressBar(fraction, ImVec2(w, h), overlay);
	return 0;
}

static int
wBullet(lua_State *L) {
	ImGui::Bullet();
	return 0;
}

static double
read_field_float(lua_State *L, const char * field, double v, int tidx = INDEX_ARGS) {
	if (lua_getfield(L, tidx, field) == LUA_TNUMBER) {
		v = lua_tonumber(L, -1);
	}
	lua_pop(L, 1);
	return v;
}

static float
read_field_checkfloat(lua_State *L, const char * field, int tidx = INDEX_ARGS) {
	float v;
	if (lua_getfield(L, tidx, field) == LUA_TNUMBER) {
		v = (float)lua_tonumber(L, -1);
	} else {
		v = 0;
		luaL_error(L, "no float %s", field);
	}
	lua_pop(L, 1);
	return v;
}

static int
read_field_int(lua_State *L, const char * field, int v, int tidx = INDEX_ARGS) {
	if (lua_getfield(L, tidx, field) == LUA_TNUMBER) {
		if (!lua_isinteger(L, -1)) {
			luaL_error(L, "Not an integer");
		}
		v = (int)lua_tointeger(L, -1);
	}
	lua_pop(L, 1);
	return v;
}

static int
read_field_checkint(lua_State *L, const char * field, int tidx = INDEX_ARGS) {
	int v;
	if (lua_getfield(L, tidx, field) == LUA_TNUMBER) {
		if (!lua_isinteger(L, -1)) {
			luaL_error(L, "Not an integer");
		}
		v = (int)lua_tointeger(L, -1);
	} else {
		v = 0;
		luaL_error(L, "no int %s", field);
	}
	lua_pop(L, 1);
	return v;
}

static const char *
read_field_string(lua_State *L, const char * field, const char *v, int tidx = INDEX_ARGS) {
	if (lua_getfield(L, tidx, field) == LUA_TSTRING) {
		v = lua_tostring(L, -1);
	}
	lua_pop(L, 1);
	return v;
}

static const char *
read_field_checkstring(lua_State *L, const char * field, int tidx = INDEX_ARGS) {
	const char * v = NULL;
	if (lua_getfield(L, tidx, field) == LUA_TSTRING) {
		v = lua_tostring(L, -1);
	}
	else {
		luaL_error(L, "no string %s", field);
	}
	lua_pop(L, 1);
	return v;
}

static const char *
read_index_string(lua_State *L, int index, const char *v, int tidx = INDEX_ARGS) {
	if (lua_geti(L, tidx, index) == LUA_TSTRING) {
		v = lua_tostring(L, -1);
	}
	lua_pop(L, 1);
	return v;
}

static bool
read_field_boolean(lua_State *L, const char *field, bool v, int tidx = INDEX_ARGS) {
	if (lua_getfield(L, tidx, field) == LUA_TBOOLEAN) {
		v = (bool)lua_toboolean(L, -1);
	}
	lua_pop(L, 1);
	return v;
}

//read table { x, y }
static ImVec2
read_field_vec2(lua_State *L, const char *field, ImVec2 def_val, int tidx = INDEX_ARGS) {
	if (lua_getfield(L, tidx, field) == LUA_TTABLE) {
		if (lua_geti(L, -1, 1) == LUA_TNUMBER)
			def_val.x = (float)lua_tonumber(L, -1);
		if (lua_geti(L, -2, 2) == LUA_TNUMBER)
			def_val.y = (float)lua_tonumber(L, -1);
		lua_pop(L, 2);
	}
	lua_pop(L, 1);
	return def_val;
}

//read table { x, y, z, w }
static ImVec4
read_field_vec4(lua_State *L, const char *field, ImVec4 def_val, int tidx = INDEX_ARGS) {
	if (lua_getfield(L, tidx, field) == LUA_TTABLE) {
		if (lua_geti(L, -1, 1) == LUA_TNUMBER)
			def_val.x = (float)lua_tonumber(L, -1);
		if (lua_geti(L, -2, 2) == LUA_TNUMBER)
			def_val.y = (float)lua_tonumber(L, -1);
		if (lua_geti(L, -3, 3) == LUA_TNUMBER)
			def_val.z = (float)lua_tonumber(L, -1);
		if (lua_geti(L, -4, 4) == LUA_TNUMBER)
			def_val.w = (float)lua_tonumber(L, -1);
		lua_pop(L, 4);
	}
	lua_pop(L, 1);
	return def_val;
}


static bool
drag_float(lua_State *L, const char *label, int n) {
	float v[4];
	int i;
	for (i = 0; i < n; i++) {
		if (lua_geti(L, INDEX_ARGS, i + 1) != LUA_TNUMBER) {
			luaL_error(L, "Need float [%d]", i + 1);
		}
		v[i] = (float)lua_tonumber(L, -1);
		lua_pop(L, 1);
	}
	float speed = (float)read_field_float(L, "speed", 1.0f);
	float min = (float)read_field_float(L, "min", 0.0f);
	float max = (float)read_field_float(L, "max", 0.0f);
	const char * format = read_field_string(L, "format", "%.3f");
	ImGuiSliderFlags flags = (ImGuiSliderFlags)read_field_int(L, "flags", ImGuiSliderFlags_None);
	bool change = false;
	switch (n) {
	case 1:
		change = ImGui::DragFloat(label, v, speed, min, max, format, flags);
		break;
	case 2:
		if (read_field_boolean(L, "range", false)) {
			const char *format_max = read_field_string(L, "format_max", NULL);
			change = ImGui::DragFloatRange2(label, v+0, v+1, speed, min, max, format, format_max, flags);
		} else {
			change = ImGui::DragFloat2(label, v, speed, min, max, format, flags);
		}
		break;
	case 3:
		change = ImGui::DragFloat3(label, v, speed, min, max, format, flags);
		break;
	case 4:
		change = ImGui::DragFloat4(label, v, speed, min, max, format, flags);
		break;
	}
	if (change) {
		for (i = 0; i < n; i++) {
			lua_pushnumber(L, v[i]);
			lua_seti(L, INDEX_ARGS, i + 1);
		}
	}
	return change;
}

static bool
drag_int(lua_State *L, const char *label, int n) {
	int v[4];
	int i;
	for (i = 0; i < n; i++) {
		if (lua_geti(L, INDEX_ARGS, i + 1) != LUA_TNUMBER || !lua_isinteger(L, -1)) {
			luaL_error(L, "Need integer [%d]", i + 1);
		}
		v[i] = (int)lua_tointeger(L, -1);
		lua_pop(L, 1);
	}
	float speed = (float)read_field_float(L, "speed", 1.0f);
	int min = read_field_int(L, "min", 0);
	int max = read_field_int(L, "max", 0);
	const char * format = read_field_string(L, "format", "%d");
	bool change = false;
	switch (n) {
	case 1:
		change = ImGui::DragInt(label, v, speed, min, max, format);
		break;
	case 2:
		if (read_field_boolean(L, "range", false)) {
			const char *format_max = read_field_string(L, "format_max", NULL);
			change = ImGui::DragIntRange2(label, v+0, v+1, speed, min, max, format, format_max);
		} else {
			change = ImGui::DragInt2(label, v, speed, min, max, format);
		}
		break;
	case 3:
		change = ImGui::DragInt3(label, v, speed, min, max, format);
		break;
	case 4:
		change = ImGui::DragInt4(label, v, speed, min, max, format);
		break;
	}
	if (change) {
		for (i = 0; i < n; i++) {
			lua_pushinteger(L, v[i]);
			lua_seti(L, INDEX_ARGS, i + 1);
		}
	}
	return change;
}

static bool
slider_float(lua_State *L, const char *label, int n) {
	float v[4];
	int i;
	for (i = 0; i < n; i++) {
		if (lua_geti(L, INDEX_ARGS, i + 1) != LUA_TNUMBER) {
			luaL_error(L, "Need float [%d]", i + 1);
		}
		v[i] = (float)lua_tonumber(L, -1);
		lua_pop(L, 1);
	}
	float min = read_field_checkfloat(L, "min");
	float max = read_field_checkfloat(L, "max");
	const char * format = read_field_string(L, "format", "%.3f");
	bool change = false;
	switch (n) {
	case 1:
		change = ImGui::SliderFloat(label, v, min, max, format);
		break;
	case 2:
		change = ImGui::SliderFloat2(label, v, min, max, format);
		break;
	case 3:
		change = ImGui::SliderFloat3(label, v, min, max, format);
		break;
	case 4:
		change = ImGui::SliderFloat4(label, v, min, max, format);
		break;
	}
	if (change) {
		for (i = 0; i < n; i++) {
			lua_pushnumber(L, v[i]);
			lua_seti(L, INDEX_ARGS, i + 1);
		}
	}
	return change;
}

static bool
slider_int(lua_State *L, const char *label, int n) {
	int v[4];
	int i;
	for (i = 0; i < n; i++) {
		if (lua_geti(L, INDEX_ARGS, i + 1) != LUA_TNUMBER || !lua_isinteger(L, -1)) {
			luaL_error(L, "Need integer [%d]", i + 1);
		}
		v[i] = (int)lua_tointeger(L, -1);
		lua_pop(L, 1);
	}
	int min = read_field_checkint(L, "min");
	int max = read_field_checkint(L, "max");
	const char * format = read_field_string(L, "format", "%d");
	bool change = false;
	switch (n) {
	case 1:
		change = ImGui::SliderInt(label, v, min, max, format);
		break;
	case 2:
		change = ImGui::SliderInt2(label, v, min, max, format);
		break;
	case 3:
		change = ImGui::SliderInt3(label, v, min, max, format);
		break;
	case 4:
		change = ImGui::SliderInt4(label, v, min, max, format);
		break;
	}
	if (change) {
		for (i = 0; i < n; i++) {
			lua_pushinteger(L, v[i]);
			lua_seti(L, INDEX_ARGS, i + 1);
		}
	}
	return change;
}

static bool
slider_angle(lua_State *L, const char *label) {
	float r;
	if (lua_geti(L, INDEX_ARGS, 1) != LUA_TNUMBER) {
		luaL_error(L, "Need float deg");
	}
	r = (float)lua_tonumber(L, -1);
	lua_pop(L, 1);
	float min = (float)read_field_float(L, "min", -360.0f);
	float max = (float)read_field_float(L, "max", +360.0f);
	const char * format = read_field_string(L, "format", "%.0f deg");
	bool change = ImGui::SliderAngle(label, &r, min, max, format);
	if (change) {
		lua_pushnumber(L, r);
		lua_seti(L, INDEX_ARGS, 1);
	}
	return change;
}

static bool
vslider_float(lua_State *L, const char *label) {
	float r;
	if (lua_geti(L, INDEX_ARGS, 1) != LUA_TNUMBER) {
		luaL_error(L, "Need float");
	}
	r = (float)lua_tonumber(L, -1);
	lua_pop(L, 1);
	float width = (float)read_field_checkfloat(L, "width");
	float height = (float)read_field_checkfloat(L, "height");
	float min = (float)read_field_checkfloat(L, "min");
	float max = (float)read_field_checkfloat(L, "max");
	const char * format = read_field_string(L, "format", "%.3f");
	ImGuiSliderFlags flags = (ImGuiSliderFlags)read_field_int(L, "flags", ImGuiSliderFlags_None);
	bool change = ImGui::VSliderFloat(label, ImVec2(width, height), &r, min, max, format, flags);
	if (change) {
		lua_pushnumber(L, r);
		lua_seti(L, INDEX_ARGS, 1);
	}
	return change;
}

static bool
vslider_int(lua_State *L, const char *label) {
	int r;
	if (lua_geti(L, INDEX_ARGS, 1) != LUA_TNUMBER) {
		luaL_error(L, "Need float");
	}
	r = (int)lua_tointeger(L, -1);
	lua_pop(L, 1);
	float width = read_field_checkfloat(L, "width");
	float height = read_field_checkfloat(L, "height");
	int min = read_field_checkint(L, "min");
	int max = read_field_checkint(L, "max");
	const char * format = read_field_string(L, "format", "%d");
	bool change = ImGui::VSliderInt(label, ImVec2(width, height), &r, min, max, format);
	if (change) {
		lua_pushinteger(L, r);
		lua_seti(L, INDEX_ARGS, 1);
	}
	return change;
}

#define DRAG_FLOAT 0
#define DRAG_INT 1
#define SLIDER_FLOAT 2
#define SLIDER_INT 3
#define SLIDER_ANGLE 4
#define VSLIDER_FLOAT 5
#define VSLIDER_INT 6

#define COLOR_EDIT 0
#define COLOR_PICKER 1

static int
wDrag(lua_State *L, int type) {
	const char * label = luaL_checkstring(L, INDEX_ID);
	luaL_checktype(L, INDEX_ARGS, LUA_TTABLE);
	lua_len(L, INDEX_ARGS);
	int n = (int)lua_tointeger(L, -1);
	lua_pop(L, 1);
	if (n < 1 || n > 4)
		return luaL_error(L, "Need 1-4 numbers");
	bool change = false;
	// todo: DragScalar/DragScalarN/SliderScalar/SliderScalarN/VSliderScalar
	switch (type) {
	case DRAG_FLOAT:
		change = drag_float(L, label, n);
		break;
	case DRAG_INT:
		change = drag_int(L, label, n);
		break;
	case SLIDER_FLOAT:
		change = slider_float(L, label, n);
		break;
	case SLIDER_INT:
		change = slider_int(L, label, n);
		break;
	case SLIDER_ANGLE:
		change = slider_angle(L, label);
		break;
	case VSLIDER_FLOAT:
		change = vslider_float(L, label);
		break;
	case VSLIDER_INT:
		change = vslider_int(L, label);
		break;
	}
	lua_pushboolean(L, change);
	return 1;
}

static int
wDragFloat(lua_State *L) {
	return wDrag(L, DRAG_FLOAT);
}

static int
wDragInt(lua_State *L) {
	return wDrag(L, DRAG_INT);
}

static int
wSliderFloat(lua_State *L) {
	return wDrag(L, SLIDER_FLOAT);
}

static int
wSliderInt(lua_State *L) {
	return wDrag(L, SLIDER_INT);
}

static int
wSliderAngle(lua_State *L) {
	return wDrag(L, SLIDER_ANGLE);
}

static int
wVSliderFloat(lua_State *L) {
	return wDrag(L, VSLIDER_FLOAT);
}

static int
wVSliderInt(lua_State *L) {
	return wDrag(L, VSLIDER_INT);
}

static int
wColor(lua_State *L, int type) {
	const char *label = luaL_checkstring(L, INDEX_ID);
	luaL_checktype(L, INDEX_ARGS, LUA_TTABLE);
	lua_len(L, INDEX_ARGS);
	int n = (int)lua_tointeger(L, -1);
	lua_pop(L, 1);
	if (n < 3 || n > 4)
		return luaL_error(L, "Need 3-4 numbers");
	ImGuiColorEditFlags flags = read_field_int(L, "flags", 0);
	float v[4];
	int i;
	for (i = 0; i < n; i++) {
		if (lua_geti(L, INDEX_ARGS, i + 1) != LUA_TNUMBER) {
			luaL_error(L, "Color should be a number");
		}
		v[i] = (float)lua_tonumber(L, -1);
		lua_pop(L, 1);
	}
	bool change;
	if (type == COLOR_EDIT) {
		if (n == 3) {
			change = ImGui::ColorEdit3(label, v, flags);
		} else {
			change = ImGui::ColorEdit4(label, v, flags);
		}
	} else {
		if (n == 3) {
			change = ImGui::ColorPicker3(label, v, flags);
		} else {
			const char * ref = NULL;
			if (lua_getfield(L, INDEX_ARGS, "ref") == LUA_TSTRING) {
				size_t sz;
				ref = lua_tolstring(L, -1, &sz);
				if (sz != 4 * sizeof(float)) {
					luaL_error(L, "Color ref should be 4 float string");
				}
			}
			lua_pop(L, 1);
			change = ImGui::ColorPicker4(label, v, flags, (const float *)ref);
		}
	}
	if (change) {
		for (i = 0; i < n; i++) {
			lua_pushnumber(L, v[i]);
			lua_seti(L, INDEX_ARGS, i + 1);
		}
	}
	lua_pushboolean(L, change);
	return 1;
}

static int
wColorEdit(lua_State *L) {
	return wColor(L, COLOR_EDIT);
}

static int
wColorPicker(lua_State *L) {
	return wColor(L, COLOR_PICKER);
}

struct editbuf {
	char * buf;
	size_t size;
	lua_State *L;
};

static int
editbuf_tostring(lua_State *L) {
	struct editbuf * ebuf = (struct editbuf *)lua_touserdata(L, 1);
	lua_pushstring(L, ebuf->buf);
	return 1;
}

static int
editbuf_release(lua_State *L) {
	struct editbuf * ebuf = (struct editbuf *)lua_touserdata(L, 1);
	lua_realloc(L, ebuf->buf, ebuf->size, 0);
	ebuf->buf = NULL;
	ebuf->size = 0;
	return 0;
}

static void
create_new_editbuf(lua_State *L) {
	size_t sz;
	const char * text = lua_tolstring(L, -1, &sz);
	if (text == NULL) {
		sz = 64;	// default buf size 64
	} else {
		++sz;
	}
#if LUA_VERSION_NUM >=504
	struct editbuf *ebuf = (struct editbuf *)lua_newuserdatauv(L, sizeof(*ebuf), 0);
#else
	struct editbuf* ebuf = (struct editbuf*)lua_newuserdata(L, sizeof(*ebuf));
#endif
	ebuf->buf = (char *)lua_realloc(L, NULL, 0, sz);
	if (ebuf->buf == NULL)
		luaL_error(L, "Edit buffer oom %u", (unsigned)sz);
	ebuf->size = sz;
	if (text) {
		memcpy(ebuf->buf, text, sz);
	} else {
		ebuf->buf[0] = 0;
	}
	if (luaL_newmetatable(L, "IMGUI_EDITBUF")) {
		lua_pushcfunction(L, editbuf_tostring);
		lua_setfield(L, -2, "__tostring");
		lua_pushcfunction(L, editbuf_release);
		lua_setfield(L, -2, "__gc");
	}
	lua_setmetatable(L, -2);
	lua_replace(L, -2);
}

static int
edit_callback(ImGuiInputTextCallbackData *data) {
	struct editbuf * ebuf = (struct editbuf *)data->UserData;
	lua_State *L = ebuf->L;
	switch (data->EventFlag) {
	case ImGuiInputTextFlags_CallbackResize: {
		size_t newsize = ebuf->size;
		while (newsize <= (size_t)data->BufTextLen) {
			newsize *= 2;
		}
		data->Buf = (char *)lua_realloc(L, ebuf->buf, ebuf->size, newsize);
		if (data->Buf == NULL) {
			data->Buf = ebuf->buf;
			data->BufTextLen = 0;
		} else {
			ebuf->buf = data->Buf;
			ebuf->size = newsize;
			data->BufSize = (int)newsize;
		}
		data->BufDirty = true;
		break;
	}
	case ImGuiInputTextFlags_CallbackCharFilter: {
		if (!lua_checkstack(L, 3)) {
			break;
		}
		if (lua_getfield(L, INDEX_ARGS, "filter") == LUA_TFUNCTION) {
			int c = data->EventChar;
			lua_pushvalue(L, 1);
			lua_pushinteger(L, c);
			if (lua_pcall(L, 2, 1, 0) != LUA_OK) {
				break;
			}
			if (lua_type(L, -1) == LUA_TNUMBER && lua_isinteger(L, -1)) {
				data->EventChar = (ImWchar)lua_tointeger(L, -1);
				lua_pop(L, 1);
			} else {
				// discard char
				lua_pop(L, 1);
				return 1;
			}
		} else {
			lua_pop(L, 1);
		}
		break;
	}
	case ImGuiInputTextFlags_CallbackHistory: {
		if (!lua_checkstack(L, 3)) {
			break;
		}
		const char * what = data->EventKey == ImGuiKey_UpArrow ? "up" : "down";
		if (lua_getfield(L, INDEX_ARGS, what) == LUA_TFUNCTION) {
			lua_pushvalue(L, 1);
			if (lua_pcall(L, 1, 1, 0) != LUA_OK) {
				break;
			}
			if (lua_type(L, -1) == LUA_TSTRING) {
				size_t sz;
				const char *str = lua_tolstring(L, -1, &sz);
				data->DeleteChars(0, data->BufTextLen);
				data->InsertChars(0, str, str + sz);
			}
			lua_pop(L, 1);
		} else {
			lua_pop(L, 1);
		}
		break;
	}
	case ImGuiInputTextFlags_CallbackCompletion: {
		if (!lua_checkstack(L, 3)) {
			break;
		}
		if (lua_getfield(L, INDEX_ARGS, "tab") == LUA_TFUNCTION) {
			lua_pushvalue(L, 1);
			lua_pushinteger(L, data->CursorPos);
			if (lua_pcall(L, 2, 1, 0) != LUA_OK) {
				break;
			}
			if (lua_type(L, -1) == LUA_TSTRING) {
				size_t sz;
				const char *str = lua_tolstring(L, -1, &sz);
				data->DeleteChars(0, data->CursorPos);
				data->InsertChars(0, str, str + sz);
				data->CursorPos = (int)sz;
			}
			lua_pop(L, 1);
		} else {
			lua_pop(L, 1);
		}
		break;
	}
	}

	return 0;
}

static int
wInputText(lua_State *L) {
	const char * label = luaL_checkstring(L, INDEX_ID);
	luaL_checktype(L, INDEX_ARGS, LUA_TTABLE);
	ImGuiInputTextFlags flags = read_field_int(L, "flags", 0);
	const char * hint = read_field_string(L, "hint", NULL);
	int t = lua_getfield(L, INDEX_ARGS, "text");
	if (t == LUA_TSTRING || t == LUA_TNIL) {
		create_new_editbuf(L);
		lua_pushvalue(L, -1);
		lua_setfield(L, INDEX_ARGS, "text");
	}
	struct editbuf * ebuf = (struct editbuf *)luaL_checkudata(L, -1, "IMGUI_EDITBUF");
	ebuf->L = L;
	bool change;
	flags |= ImGuiInputTextFlags_CallbackResize;
	int top = lua_gettop(L);
	if (flags & ImGuiInputTextFlags_Multiline) {
		float width = (float)read_field_float(L, "width", 0);
		float height = (float)read_field_float(L, "height", 0);
		change = ImGui::InputTextMultiline(label, ebuf->buf, ebuf->size, ImVec2(width, height), flags, edit_callback, ebuf);
	} else {
		if (hint) {
			change = ImGui::InputTextWithHint(label, hint, ebuf->buf, ebuf->size, flags, edit_callback, ebuf);
		} else {
			change = ImGui::InputText(label, ebuf->buf, ebuf->size, flags, edit_callback, ebuf);
		}
	}
	if (lua_gettop(L) != top) {
		lua_error(L);
	}
	lua_pushboolean(L, change);
	return 1;
}

static bool
input_float(lua_State *L, const char *label, const char *format, ImGuiInputTextFlags flags, int n) {
	if (n == 1) {
		double step = read_field_float(L, "step", 0);
		double step_fast = read_field_float(L, "step_fast", 0);
		lua_geti(L, INDEX_ARGS, 1);
		double v = lua_tonumber(L, -1);
		lua_pop(L, 1);
		bool r = ImGui::InputDouble(label, &v, step, step_fast, format, flags);
		if (r) {
			lua_pushnumber(L, v);
			lua_seti(L, INDEX_ARGS, 1);
		}
		return r;
	} else {
		float v[4];
		int i;
		for (i=0;i<n;i++) {
			lua_geti(L, INDEX_ARGS, i + 1);
			v[i] = (float)lua_tonumber(L, -1);
			lua_pop(L, 1);
		}
		bool r = false;
		switch (n) {
		case 2:
			r = ImGui::InputFloat2(label, v, format, flags);
			break;
		case 3:
			r = ImGui::InputFloat3(label, v, format, flags);
			break;
		case 4:
			r = ImGui::InputFloat4(label, v, format, flags);
			break;
		}
		if (r) {
			for (i = 0; i < n; i++) {
				lua_pushnumber(L, v[i]);
				lua_seti(L, INDEX_ARGS, i + 1);
			}
		}
		return r;
	}
}

static bool
input_int(lua_State *L, const char *label, ImGuiInputTextFlags flags, int n) {
	int step = 1;
	int step_fast = 100;
	if (n > 1) {
		step = read_field_int(L, "step", 1);
		step_fast = read_field_int(L, "step_fast", 100);
	}
	int v[4];
	int i;
	for (i = 0; i < n; i++) {
		lua_geti(L, INDEX_ARGS, i + 1);
		v[i] = (int)lua_tointeger(L, -1);
		lua_pop(L, 1);
	}
	bool r = false;
	switch (n) {
	case 1:
		r = ImGui::InputInt(label, v, step, step_fast, flags);
		break;
	case 2:
		r = ImGui::InputInt2(label, v, flags);
		break;
	case 3:
		r = ImGui::InputInt3(label, v, flags);
		break;
	case 4:
		r = ImGui::InputInt4(label, v, flags);
		break;
	}
	if (r) {
		for (i = 0; i < n; i++) {
			lua_pushinteger(L, v[i]);
			lua_seti(L, INDEX_ARGS, i + 1);
		}
	}
	return r;
}

static int
wInputFloat(lua_State *L) {
	const char * label = luaL_checkstring(L, INDEX_ID);
	luaL_checktype(L, INDEX_ARGS, LUA_TTABLE);
	lua_len(L, INDEX_ARGS);
	int n = (int)lua_tointeger(L, -1);
	lua_pop(L, 1);
	if (n < 1 || n > 4)
		return luaL_error(L, "Need 1-4 numbers");
	ImGuiInputTextFlags flags = read_field_int(L, "flags", 0);
	const char * format = read_field_string(L, "format", "%.3f");
	bool change = input_float(L, label, format, flags, n);
	lua_pushboolean(L, change);
	return 1;
}

static int
wInputInt(lua_State *L) {
	const char * label = luaL_checkstring(L, INDEX_ID);
	luaL_checktype(L, INDEX_ARGS, LUA_TTABLE);
	lua_len(L, INDEX_ARGS);
	int n = (int)lua_tointeger(L, -1);
	lua_pop(L, 1);
	if (n < 1 || n > 4)
		return luaL_error(L, "Need 1-4 int");
	ImGuiInputTextFlags flags = read_field_int(L, "flags", 0);
	bool change = input_int(L, label, flags, n);
	lua_pushboolean(L, change);
	return 1;
}

static int
wText(lua_State *L) {
	size_t sz;
	const char * text = luaL_checklstring(L, 1, &sz);
	float color[4];
	switch (lua_gettop(L)) {
	case 1:	// no color
		ImGui::TextUnformatted(text, text + sz);
		break;
	case 4:	// RGB
	case 5: // RGBA
		color[0] = (float)luaL_checknumber(L, 2);
		color[1] = (float)luaL_checknumber(L, 3);
		color[2] = (float)luaL_checknumber(L, 4);
		color[3] = (float)luaL_optnumber(L, 5, 1.0);
		ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(color[0], color[1], color[2], color[3]));
		ImGui::TextUnformatted(text, text + sz);
		ImGui::PopStyleColor();
		break;
	default:
		luaL_error(L, "Invalid args number for Text");
	}
	return 0;
}

static int
wPropertyLabel(lua_State* L) {
	size_t sz;
	const char* label = luaL_checklstring(L, 1, &sz);
	ImGuiWindow* window = ImGui::GetCurrentWindow();
	const ImGuiStyle& style = ImGui::GetStyle();
	const ImVec2 lineStart = ImGui::GetCursorScreenPos();

	float fullWidth = ImGui::GetContentRegionAvail().x;
	float itemWidth = ImGui::CalcItemWidth() + style.ItemSpacing.x;
	ImVec2 textSize = ImGui::CalcTextSize(label);
	ImRect textRect;
	textRect.Min = ImGui::GetCursorScreenPos();
	// TODO: support right style
	bool isLeft = true;
	if (!isLeft)
        textRect.Min.x = textRect.Min.x + itemWidth;
	textRect.Max = textRect.Min;
	textRect.Max.x += fullWidth - itemWidth;
	textRect.Max.y += textSize.y;

	ImGui::SetCursorScreenPos(textRect.Min);

	ImGui::AlignTextToFramePadding();
	textRect.Min.y += window->DC.CurrLineTextBaseOffset;
	textRect.Max.y += window->DC.CurrLineTextBaseOffset;

	ImGui::ItemSize(textRect);
	if (ImGui::ItemAdd(textRect, window->GetID(label))) {
		ImGui::RenderTextEllipsis(ImGui::GetWindowDrawList(), textRect.Min, textRect.Max, textRect.Max.x,
			textRect.Max.x, label, nullptr, &textSize);

		if (textRect.GetWidth() < textSize.x && ImGui::IsItemHovered())
			ImGui::SetTooltip("%s", label);
	}

	if (isLeft) {
		ImGui::SetCursorScreenPos({ textRect.Max.x, textRect.Max.y - (textSize.y + window->DC.CurrLineTextBaseOffset) });
		ImGui::SameLine();
	}
	else {
		ImGui::SetCursorScreenPos(lineStart);
	}
	ImGui::SetNextItemWidth(ImGui::GetContentRegionAvail().x);
	return 0;
}

static int
wTextDisabled(lua_State *L) {
	size_t sz;
	const char * text = luaL_checklstring(L, 1, &sz);
	ImGui::PushStyleColor(ImGuiCol_Text, ImGui::GetStyle().Colors[ImGuiCol_TextDisabled]);
	ImGui::TextUnformatted(text, text + sz);
	ImGui::PopStyleColor();
	return 0;
}

static int
wTextWrapped(lua_State *L) {
	size_t sz;
	const char * text = luaL_checklstring(L, 1, &sz);
	float wrap = (float)luaL_optnumber(L, 2, 0.0f);
	ImGui::PushTextWrapPos(wrap);
	ImGui::TextUnformatted(text, text + sz);
	ImGui::PopTextWrapPos();
	return 0;
}

static int
wLabelText(lua_State *L) {
	const char * label = luaL_checkstring(L, 1);
	const char * text = luaL_checkstring(L, 2);
	ImGui::LabelText(label, "%s", text);
	return 0;
}

static int
wBulletText(lua_State *L) {
	const char * text = luaL_checkstring(L, 1);
	ImGui::BulletText("%s", text);
	return 0;
}

static int
wBeginCombo(lua_State *L) {
	const char *label = luaL_checkstring(L, INDEX_ID);
	const char * preview_value;
	ImGuiComboFlags flags = 0;
	switch (lua_type(L, INDEX_ARGS)) {
	case LUA_TTABLE:
		preview_value = read_index_string(L, 1, NULL);
		flags = read_field_int(L, "flags", 0);
		break;
	case LUA_TSTRING:
		preview_value = lua_tostring(L, INDEX_ARGS);
		break;
	case LUA_TNIL:
	case LUA_TNONE:
		preview_value = NULL;
		break;
	default:
		return luaL_error(L, "Invalid preview value type %s", lua_typename(L, lua_type(L, INDEX_ARGS)));
	}
	bool change = ImGui::BeginCombo(label, preview_value, flags);
	lua_pushboolean(L, change);
	return 1;
}

static int
wEndCombo(lua_State *L) {
	ImGui::EndCombo();
	return 0;
}

static int
wSelectable(lua_State *L) {
	const char *label = luaL_checkstring(L, INDEX_ID);
	bool selected;
	ImGuiSelectableFlags flags = 0;
	ImVec2 size(0, 0);
	int t = lua_type(L, INDEX_ARGS);
	switch (t) {
	case LUA_TNIL:
	case LUA_TBOOLEAN:
		selected = lua_toboolean(L, INDEX_ARGS);
		size.x = (float)luaL_optnumber(L, 3, 0.0f);
		size.y = (float)luaL_optnumber(L, 4, 0.0f);
		flags = lua_getflags<ImGuiSelectableFlags>(L, 5, ImGuiSelectableFlags_None);
		if (lua_toboolean(L, 6)) {
			flags |= ImGuiSelectableFlags_Disabled;
		}
		break;
	case LUA_TTABLE:
		if (lua_geti(L, INDEX_ARGS, 1) == LUA_TSTRING &&
			lua_compare(L, INDEX_ID, -1, LUA_OPEQ)) {
			selected = true;
		} else {
			selected = false;
		}
		lua_pop(L, 1);
		flags = read_field_int(L, "item_flags", 0);
		size.x = (float)read_field_float(L, "width", 0);
		size.y = (float)read_field_float(L, "height", 0);
		if (lua_toboolean(L, 3)) {
			flags |= ImGuiSelectableFlags_Disabled;
		}
		break;
	default:
		return luaL_error(L, "Invalid selected type %s", lua_typename(L, t));
	}
	
	bool change = ImGui::Selectable(label, selected, flags, size);
	if (change && t == LUA_TTABLE) {
		lua_pushvalue(L, INDEX_ID);
		lua_seti(L, INDEX_ARGS, 1);
	}
	lua_pushboolean(L, change);
	return 1;
}

// todo: TreePush/CollapsingHeader (with p_open)
static int
wTreeNode(lua_State *L) {
	const char * label = luaL_checkstring(L, INDEX_ID);
	auto flags = lua_getflags<ImGuiTreeNodeFlags>(L, 2, ImGuiTreeNodeFlags_None);
	bool change = ImGui::TreeNodeEx(label, flags);
	lua_pushboolean(L, change);
	return 1;
}

static int
wTreePush(lua_State* L) {
	const char* label = luaL_checkstring(L, INDEX_ID);
	ImGui::TreePush(label);
	return 0;
}

static int
wTreePop(lua_State *L) {
	ImGui::TreePop();
	return 0;
}

static int
wSetNextItemOpen(lua_State *L) {
	bool is_open = lua_toboolean(L, 1);
	ImGuiCond c = get_cond(L, 2);
	ImGui::SetNextItemOpen(is_open, c);
	return 0;
}

static int
wCollapsingHeader(lua_State *L) {
	const char *label = luaL_checkstring(L, INDEX_ID);
	auto flags = lua_getflags<ImGuiTreeNodeFlags>(L, 2, ImGuiTreeNodeFlags_None);
	bool change = ImGui::CollapsingHeader(label, flags);
	lua_pushboolean(L, change);
	return 1;
}

#define PLOT_LINES 0
#define PLOT_HISTOGRAM 1

static int
get_plot_func(lua_State *L) {
	int n = (int)lua_tointeger(L, 2);
	if (lua_geti(L, 1, n) != LUA_TNUMBER) {
		return luaL_error(L, "Need a number at [%d], it's a %s", n, lua_typename(L, lua_type(L, -1)));
	}
	return 1;
}

static float
get_plot(void* data, int idx) {
	struct lua_args *args = (struct lua_args *)data;
	lua_State *L = args->L;
	if (args->err)
		return 0;
	lua_pushcfunction(L, get_plot_func);
	lua_pushvalue(L, INDEX_ARGS);
	lua_pushinteger(L, idx + 1);
	if (lua_pcall(L, 2, 1, 0) != LUA_OK) {
		args->err = true;
		return 0;
	}
	float r = (float)lua_tonumber(L, -1);
	lua_pop(L, 1);
	return r;
}

static void
plot(lua_State *L, int t) {
	const char *label = luaL_checkstring(L, INDEX_ID);
	luaL_checktype(L, INDEX_ARGS, LUA_TTABLE);
	lua_len(L, INDEX_ARGS);
	int n = (int)lua_tointeger(L, -1);
	lua_pop(L, 1);
	int values_offset = read_field_int(L, "offset", 0);
	const char * overlay_text = read_field_string(L, "text", NULL);
	float scale_min = (float)read_field_float(L, "min", FLT_MAX);
	float scale_max = (float)read_field_float(L, "max", FLT_MAX);
	float width = (float)read_field_float(L, "width", 0);
	float height = (float)read_field_float(L, "height", 0);
	struct lua_args args = { L, false };
	if (t == PLOT_LINES) {
		ImGui::PlotLines(label, get_plot, &args, n, values_offset, overlay_text, scale_min, scale_max, ImVec2(width, height));
	} else {
		ImGui::PlotHistogram(label, get_plot, &args, n, values_offset, overlay_text, scale_min, scale_max, ImVec2(width, height));
	}
	if (args.err) {
		lua_error(L);
	}
}

static int
wPlotLines(lua_State *L) {
	plot(L, PLOT_LINES);
	return 0;
}

static int
wPlotHistogram(lua_State *L) {
	plot(L, PLOT_HISTOGRAM);
	return 0;
}

static int
wBeginTooltip(lua_State *L) {
	bool change = ImGui::BeginTooltip();
	lua_pushboolean(L, change);
	return 1;
}

static int
wEndTooltip(lua_State *L) {
	ImGui::EndTooltip();
	return 0;
}

static int
wSetTooltip(lua_State *L) {
	const char *tooltip = luaL_checkstring(L, 1);
	ImGui::SetTooltip("%s", tooltip);
	return 0;
}

static int
wBeginMainMenuBar(lua_State *L) {
	bool change = ImGui::BeginMainMenuBar();
	lua_pushboolean(L, change);
	return 1;
}

static int
wEndMainMenuBar(lua_State *L) {
	ImGui::EndMainMenuBar();
	return 0;
}

static int
wBeginMenuBar(lua_State *L) {
	bool change = ImGui::BeginMenuBar();
	lua_pushboolean(L, change);
	return 1;
}

static int
wEndMenuBar(lua_State *L) {
	ImGui::EndMenuBar();
	return 0;
}

static int
wBeginMenu(lua_State *L) {
	const char * label = luaL_checkstring(L, INDEX_ID);
	bool enabled = true;
	if (lua_isboolean(L, 2)) {
		enabled = lua_toboolean(L, 2);
	}
	bool change = ImGui::BeginMenu(label, enabled);
	lua_pushboolean(L, change);
	return 1;
}

static int
wEndMenu(lua_State *L) {
	ImGui::EndMenu();
	return 0;
}

static int
wMenuItem(lua_State *L) {
	const char * label = luaL_checkstring(L, INDEX_ID);
	const char *shortcut = luaL_optstring(L, 2, NULL);
	bool enabled = true;
	if (lua_isboolean(L, 4)) {
		enabled = lua_toboolean(L, 4);
	}
	if (lua_isboolean(L, 3)) {
		bool selected = lua_toboolean(L, 3);
		bool change = ImGui::MenuItem(label, shortcut, &selected, enabled);
		lua_pushboolean(L, change);
		lua_pushboolean(L, selected);
		return 2;
	}
	else
	{
		bool change = ImGui::MenuItem(label, shortcut, false, enabled);
		lua_pushboolean(L, change);
		return 1;
	}


}

static int
wBeginListBox(lua_State *L) {
	const char *label = luaL_checkstring(L, INDEX_ID);
	float width = (float)luaL_optnumber(L, 2, 0);
	float height = (float)luaL_optnumber(L, 3, 0);
	bool change = ImGui::BeginListBox(label, ImVec2(width, height));
	lua_pushboolean(L, change);
	return 1;
}

static int
wEndListBox(lua_State *L) {
	ImGui::EndListBox();
	return 0;
}

static int
get_listitem_func(lua_State *L) {
	int n = (int)lua_tointeger(L, 2);
	lua_geti(L, 1, n);
	return 1;
}

static const char*
get_listitem(void* data, int idx) {
	struct lua_args *args = (struct lua_args *)data;
	lua_State *L = args->L;
	if (args->err)
		return nullptr;
	lua_pushcfunction(L, get_listitem_func);
	lua_pushvalue(L, INDEX_ARGS);
	lua_pushinteger(L, idx + 1);
	if (lua_pcall(L, 2, 1, 0) != LUA_OK) {
		args->err = true;
		return 0;
	}
	if (lua_type(L, -1) == LUA_TSTRING) {
		return lua_tostring(L, -1);
	}
	lua_pop(L, 1);
	return nullptr;
}

static int
wListBox(lua_State *L) {
	const char *label = luaL_checkstring(L, INDEX_ID);
	luaL_checktype(L, INDEX_ARGS, LUA_TTABLE);
	lua_len(L, INDEX_ARGS);
	int n = (int)lua_tointeger(L, -1);
	lua_pop(L, 1);
	int height_in_items = read_field_int(L, "height", -1);
	struct lua_args args = { L, false };
	int current = read_field_int(L, "current", 0) - 1;
	bool change = ImGui::ListBox(label, &current, get_listitem, &args, n, height_in_items);
	if (change) {
		lua_pushinteger(L, current + 1);
		lua_setfield(L, INDEX_ARGS, "current");
	}
	lua_pushboolean(L, change);
	return 1;
}



static int wImage(lua_State *L) {
	int lua_handle = (int)luaL_checkinteger(L, 1);
	ImTextureID tex_id = rendererGetTextureID(L, lua_handle);
	float size_x = (float)luaL_checknumber(L, 2);
	float size_y = (float)luaL_checknumber(L, 3);
	ImVec2 size = { size_x, size_y };

	ImVec2 uv0 = { 0.0f,0.0f };
	ImVec2 uv1 = { 1.0f,1.0f };
	ImVec4 tint_col = { 1.0f,1.0f,1.0f,1.0f };
	ImVec4 border_col = { 0.0f,0.0f,0.0f,0.0f };

	if (lua_type(L, 4) == LUA_TTABLE)
	{
		uv0 = read_field_vec2(L, "uv0", uv0, 4);
		uv1 = read_field_vec2(L, "uv1", uv1, 4);
		tint_col = read_field_vec4(L, "tint_col", tint_col, 4);
		border_col = read_field_vec4(L, "border_col", border_col, 4);
	}
	ImGui::Image(tex_id, size, uv0, uv1, tint_col, border_col);
	return 0;
}

static int
wImageButton(lua_State *L) {
	const char * id = luaL_checkstring(L, INDEX_ID);
	int lua_handle = (int)luaL_checkinteger(L, 2);
	ImTextureID tex_id = rendererGetTextureID(L, lua_handle);
	float size_x = (float)luaL_checknumber(L, 3);
	float size_y = (float)luaL_checknumber(L, 4);
	ImVec2 size = { size_x, size_y };

	ImVec2 uv0 = { 0.0f,0.0f };
	ImVec2 uv1 = { 1.0f,1.0f };
	ImVec4 bg_col = { 0.0f,0.0f,0.0f,0.0f };
	ImVec4 tint_col = { 1.0f,1.0f,1.0f,1.0f };

	if (lua_type(L, 5) == LUA_TTABLE)
	{
		uv0 = read_field_vec2(L, "uv0", uv0, 5);
		uv1 = read_field_vec2(L, "uv1", uv1, 5);
		bg_col = read_field_vec4(L, "bg_col", bg_col, 5);
		tint_col = read_field_vec4(L, "tint_col", tint_col, 5);
	}
	bool clicked = ImGui::ImageButton(id, tex_id, size, uv0, uv1, bg_col, tint_col);
	lua_pushboolean(L, clicked);
	return 1;
}

static int
wBeginDragDropSource(lua_State * L) {
	auto flags = lua_getflags<ImGuiDragDropFlags>(L, 1, ImGuiDragDropFlags_None);
	bool change = ImGui::BeginDragDropSource(flags);
	lua_pushboolean(L, change);
	return 1;
}

static int
wEndDragDropSource(lua_State * L) {
	ImGui::EndDragDropSource();
	return 0;
}

static int
wSetDragDropPayload(lua_State * L) {
	const char * type = luaL_checkstring(L, 1);
	const char * data = luaL_optstring(L, 2,NULL);
	ImGuiCond cond = get_cond(L, 3);
	bool change = ImGui::SetDragDropPayload(type, data, strlen(data), cond);
	lua_pushboolean(L, change);
	return 0;
}

static int
wBeginDragDropTarget(lua_State * L) {
	bool change = ImGui::BeginDragDropTarget();
	lua_pushboolean(L, change);
	return 1;
}

static int
wEndDragDropTarget(lua_State * L) {
	ImGui::EndDragDropTarget();
	return 0;
}

//data or nil = AcceptDragDropPayload( type,ImGuiDragDropFlags );
//change = AcceptDragDropPayload( { type=[in],flags==[in],data=[out],isPreview=[out],isDelivery=[out] } );
static int
wAcceptDragDropPayload(lua_State * L) {
	bool is_table_arg = lua_istable(L, 1);
	const char * type;
	ImGuiDragDropFlags flags;
	if (is_table_arg) {
		type = read_field_checkstring(L, "type", 1);
		flags = read_field_int(L, "flags", 0, 1);
	}
	else {
		type = luaL_checkstring(L, 1);
		flags = lua_getflags<ImGuiDragDropFlags>(L, 2, ImGuiDragDropFlags_None);
	}
	const ImGuiPayload * payload = ImGui::AcceptDragDropPayload(type, flags);
	if (payload != NULL){
		if (is_table_arg){
			lua_pushlstring(L, (const char *)payload->Data,payload->DataSize);
			lua_setfield(L, 1, "data");
			lua_pushboolean(L, payload->IsPreview());
			lua_setfield(L, 1, "isPreview");
			lua_pushboolean(L, payload->IsDelivery());
			lua_setfield(L, 1, "isDelivery");
			lua_pushboolean(L, true);
		}
		else {
			const char * data = (const char *)payload->Data;
			lua_pushlstring(L, data, payload->DataSize);
		}
	}
	else{
		if (is_table_arg)
			lua_pushboolean(L, false);
		else
			lua_pushnil(L);
	}
	return 1;
}

static int
wGetDragDropPayload(lua_State* L) {
	const ImGuiPayload* payload = ImGui::GetDragDropPayload();
	if (payload != NULL) {
		const char* data = (const char*)payload->Data;
		lua_pushlstring(L, data, payload->DataSize);
	}
	else {
		lua_pushnil(L);
	}
	return 1;
}

static int
wPushTextWrapPos(lua_State* L) {
	float pos = (float)luaL_optnumber(L, 1, 0.0f);
	ImGui::PushTextWrapPos(pos);
	return 0;
}

static int
wPopTextWrapPos(lua_State* L) {
	ImGui::PopTextWrapPos();
	return 0;
}

static int
wSelectableInput(lua_State* L) {
	const char* label = luaL_checkstring(L, INDEX_ID);
	bool selected;
	ImGuiSelectableFlags flags = 0;
	ImVec2 size(0, 0);
	int t = lua_type(L, INDEX_ARGS);
	switch (t) {
	case LUA_TNIL:
	case LUA_TBOOLEAN:
		selected = lua_toboolean(L, INDEX_ARGS);
		size.x = (float)luaL_optnumber(L, 3, 0.0f);
		size.y = (float)luaL_optnumber(L, 4, 0.0f);
		flags = lua_getflags<ImGuiSelectableFlags>(L, 5, ImGuiSelectableFlags_None);
		if (lua_toboolean(L, 6)) {
			flags |= ImGuiSelectableFlags_Disabled;
		}
		break;
	case LUA_TTABLE:
		if (lua_geti(L, INDEX_ARGS, 1) == LUA_TSTRING &&
			lua_compare(L, INDEX_ID, -1, LUA_OPEQ)) {
			selected = true;
		}
		else {
			selected = false;
		}
		lua_pop(L, 1);
		flags = read_field_int(L, "item_flags", 0);
		size.x = (float)read_field_float(L, "width", 0);
		size.y = (float)read_field_float(L, "height", 0);
		if (lua_toboolean(L, 3)) {
			flags |= ImGuiSelectableFlags_Disabled;
		}
		break;
	default:
		return luaL_error(L, "Invalid selected type %s", lua_typename(L, t));
	}

	bool change = ImGui::Selectable(label, selected, flags, size);
	if (change && t == LUA_TTABLE) {
		lua_pushvalue(L, INDEX_ID);
		lua_seti(L, INDEX_ARGS, 1);
	}
	lua_pushboolean(L, change);
	return 1;

	//const char* label = luaL_checkstring(L, INDEX_ID);
// 	luaL_checktype(L, INDEX_ARGS, LUA_TTABLE);
// 	ImGuiInputTextFlags flags = read_field_int(L, "flags", 0);
// 	const char* hint = read_field_string(L, "hint", NULL);
// 	int t = lua_getfield(L, INDEX_ARGS, "text");
// 	if (t == LUA_TSTRING || t == LUA_TNIL) {
// 		create_new_editbuf(L);
// 		lua_pushvalue(L, -1);
// 		lua_setfield(L, INDEX_ARGS, "text");
// 	}
// 	struct editbuf* ebuf = (struct editbuf*)luaL_checkudata(L, -1, "IMGUI_EDITBUF");
// 	ebuf->L = L;
// 	bool change;
// 	flags |= ImGuiInputTextFlags_CallbackResize;
// 	int top = lua_gettop(L);
// 	if (hint) {
// 		change = ImGui::InputTextWithHint(label, hint, ebuf->buf, ebuf->size, flags, edit_callback, ebuf);
// 	}
// 	else {
// 		change = ImGui::InputText(label, ebuf->buf, ebuf->size, flags, edit_callback, ebuf);
// 	}
// 	if (lua_gettop(L) != top) {
// 		lua_error(L);
// 	}
// 	lua_pushboolean(L, change);
// 	return 1;
}


#ifdef _MSC_VER
#pragma endregion IMP_WIDGET
#endif

// windows api
#ifdef _MSC_VER
#pragma region IMP_WINDOWS
#endif

#define NO_CLOSED ((lua_Integer)1 << 32)

struct window_args {
	const char * id;
	bool *p_open;
	bool opened;
	unsigned int flags;
};

static void
get_window_args(lua_State *L, struct window_args *args) {
	args->id = luaL_checkstring(L, INDEX_ID);
	lua_Integer flagsx = luaL_optinteger(L, 2, 0);
	args->flags = (unsigned int)(flagsx & 0xffffffff);
	args->opened = true;
	args->p_open = &args->opened;
	if (flagsx & NO_CLOSED) {
		args->p_open = NULL;
	}
}

static int
winBegin(lua_State *L) {
	struct window_args args;
	get_window_args(L, &args);
	bool change = ImGui::Begin(args.id, args.p_open, args.flags);
	lua_pushboolean(L, change);
	lua_pushboolean(L, args.opened);
	return 2;
}

static int
winEnd(lua_State *L) {
	ImGui::End();
	return 0;
}

static int
winBeginDisabled(lua_State *L) {
	bool disabled = (bool)lua_toboolean(L, 1);
	ImGui::BeginDisabled(disabled);
	return 0;
}

static int
winEndDisabled(lua_State *L) {
	ImGui::EndDisabled();
	return 0;
}

static int
winBeginChild(lua_State *L) {
	const char * id = luaL_checkstring(L, INDEX_ID);
	float width = (float)luaL_optnumber(L, 2, 0);
	float height = (float)luaL_optnumber(L, 3, 0);
	auto child_flags = lua_getflags<ImGuiChildFlags>(L, 4, ImGuiChildFlags_None);
	auto window_flags = lua_getflags<ImGuiWindowFlags>(L, 5, ImGuiWindowFlags_None);
	bool change = ImGui::BeginChild(id, ImVec2(width, height), child_flags, window_flags);
	lua_pushboolean(L, change);
	return 1;
}

static int
winEndChild(lua_State *L) {
	ImGui::EndChild();
	return 0;
}

static int
winBeginTabBar(lua_State *L) {
	const char * id = luaL_checkstring(L, INDEX_ID);
	auto flags = lua_getflags<ImGuiTabBarFlags>(L, 2, ImGuiTabBarFlags_None);
	bool change = ImGui::BeginTabBar(id, flags);
	lua_pushboolean(L, change);
	return 1;
}

static int
winEndTabBar(lua_State *L) {
	ImGui::EndTabBar();
	return 0;
}

static int
winBeginTabItem(lua_State *L) {
	struct window_args args;
	get_window_args(L, &args);
	bool change = ImGui::BeginTabItem(args.id, args.p_open, args.flags);
	lua_pushboolean(L, change);
	lua_pushboolean(L, args.opened);
	return 2;
}

static int
winEndTabItem(lua_State *L) {
	ImGui::EndTabItem();
	return 0;
}

static int
winSetTabItemClosed(lua_State *L) {
	const char * tab_or_docked_window_label = luaL_checkstring(L, 1);
	ImGui::SetTabItemClosed(tab_or_docked_window_label);
	return 0;
}

static int
winOpenPopup(lua_State *L) {
	if (lua_isinteger(L, INDEX_ID)) {
		ImGuiID id = (ImGuiID)lua_tointeger(L, INDEX_ID);
		auto flags = lua_getflags<ImGuiPopupFlags>(L, INDEX_ARGS, ImGuiPopupFlags_None);
		ImGui::OpenPopup(id, flags);
	}
	else {
		const char * id = luaL_checkstring(L, INDEX_ID);
		auto flags = lua_getflags<ImGuiPopupFlags>(L, INDEX_ARGS, ImGuiPopupFlags_None);
		ImGui::OpenPopup(id, flags);
	}
	return 0;
}

static int
winBeginPopup(lua_State *L) {
	const char * id = luaL_checkstring(L, INDEX_ID);
	auto flags = lua_getflags<ImGuiWindowFlags>(L, INDEX_ARGS, ImGuiWindowFlags_None);
	bool change = ImGui::BeginPopup(id, flags);
	lua_pushboolean(L, change);
	return 1;
}

static int
winBeginPopupContextItem(lua_State *L) {
	const char * id = luaL_checkstring(L, INDEX_ID);
	auto flags = lua_getflags<ImGuiPopupFlags>(L, INDEX_ARGS, ImGuiPopupFlags_MouseButtonRight);
	int change = ImGui::BeginPopupContextItem(id, flags);
	lua_pushboolean(L, change);
	return 1;
}

static int
winBeginPopupContextWindow(lua_State *L) {
	const char * id = luaL_checkstring(L, INDEX_ID);
	auto flags = lua_getflags<ImGuiPopupFlags>(L, INDEX_ARGS, ImGuiPopupFlags_MouseButtonRight);
	int change = ImGui::BeginPopupContextWindow(id, flags);
	lua_pushboolean(L, change);
	return 1;
}

static int
winBeginPopupContextVoid(lua_State *L) {
	const char * id = luaL_checkstring(L, INDEX_ID);
	auto flags = lua_getflags<ImGuiPopupFlags>(L, INDEX_ARGS, ImGuiPopupFlags_MouseButtonRight);
	int change = ImGui::BeginPopupContextVoid(id, flags);
	lua_pushboolean(L, change);
	return 1;
}

static int
winBeginPopupModal(lua_State *L) {
	struct window_args args;
	get_window_args(L, &args);
	bool change = ImGui::BeginPopupModal(args.id, args.p_open, args.flags);
	lua_pushboolean(L, change);
	lua_pushboolean(L, args.opened);
	return 2;
}

static int
winEndPopup(lua_State *L) {
	ImGui::EndPopup();
	return 0;
}

static int
winOpenPopupOnItemClick(lua_State *L) {
	const char * id = luaL_checkstring(L, INDEX_ID);
	auto flags = lua_getflags<ImGuiPopupFlags>(L, INDEX_ARGS, ImGuiPopupFlags_MouseButtonRight);
	ImGui::OpenPopupOnItemClick(id, flags);
	return 0;
}

static int
winIsPopupOpen(lua_State *L) {
	const char * id = luaL_checkstring(L, INDEX_ID);
	bool change = ImGui::IsPopupOpen(id);
	lua_pushboolean(L, change);
	return 1;
}

static int
winCloseCurrentPopup(lua_State *L) {
	ImGui::CloseCurrentPopup();
	return 0;
}

static int
winIsWindowAppearing(lua_State *L) {
	bool v = ImGui::IsWindowAppearing();
	lua_pushboolean(L, v);
	return 1;
}

static int
winIsWindowCollapsed(lua_State *L) {
	bool v = ImGui::IsWindowCollapsed();
	lua_pushboolean(L, v);
	return 1;
}

static int
winIsWindowFocused(lua_State *L) {
	auto flags = lua_getflags<ImGuiFocusedFlags>(L, 1, ImGuiFocusedFlags_None);
	bool v = ImGui::IsWindowFocused(flags);
	lua_pushboolean(L, v);
	return 1;
}

static int
winIsWindowHovered(lua_State *L) {
	auto flags = lua_getflags<ImGuiHoveredFlags>(L, 1, ImGuiHoveredFlags_None);
	bool v = ImGui::IsWindowHovered(flags);
	lua_pushboolean(L, v);
	return 1;
}

static int
winGetWindowPos(lua_State *L) {
	ImVec2 v = ImGui::GetWindowPos();
	lua_pushnumber(L, v.x);
	lua_pushnumber(L, v.y);
	return 2;
}

static int
winGetWindowSize(lua_State *L) {
	ImVec2 v = ImGui::GetWindowSize();
	lua_pushnumber(L, v.x);
	lua_pushnumber(L, v.y);
	return 2;
}

static int
winGetScrollX(lua_State *L) {
	float v = ImGui::GetScrollX();
	lua_pushnumber(L, v);
	return 1;
}

static int
winGetScrollY(lua_State *L) {
	float v = ImGui::GetScrollY();
	lua_pushnumber(L, v);
	return 1;
}

static int
winGetScrollMaxX(lua_State *L) {
	float v = ImGui::GetScrollMaxX();
	lua_pushnumber(L, v);
	return 1;
}

static int
winGetScrollMaxY(lua_State *L) {
	float v = ImGui::GetScrollMaxY();
	lua_pushnumber(L, v);
	return 1;
}

static int
winSetScrollX(lua_State *L) {
	float v = (float)luaL_checknumber(L, 1);
	ImGui::SetScrollX(v);
	return 0;
}

static int
winSetScrollY(lua_State *L) {
	float v = (float)luaL_checknumber(L, 1);
	ImGui::SetScrollY(v);
	return 0;
}

static int
winSetScrollHereY(lua_State *L) {
	float v = (float)luaL_optnumber(L, 1, 0.5);
	ImGui::SetScrollHereY(v);
	return 0;
}

static int
winSetScrollFromPosY(lua_State *L) {
	float local_y = (float)luaL_checknumber(L, 1);
	float v = (float)luaL_optnumber(L, 2, 0.5);
	ImGui::SetScrollFromPosY(local_y, v);
	return 0;
}

static int
winSetNextWindowPos(lua_State *L) {
	float x = (float)luaL_checknumber(L, 1);
	float y = (float)luaL_checknumber(L, 2);
	ImGuiCond cond = get_cond(L, 3);
	float px = (float)luaL_optnumber(L, 4, 0);
	float py = (float)luaL_optnumber(L, 5, 0);
	ImGui::SetNextWindowPos(ImVec2(x, y), cond, ImVec2(px, py));
	return 0;
}

static int
winSetNextWindowSize(lua_State *L) {
	float x = (float)luaL_checknumber(L, 1);
	float y = (float)luaL_checknumber(L, 2);
	ImGuiCond cond = get_cond(L, 3);
	ImGui::SetNextWindowSize(ImVec2(x, y), cond);
	return 0;
}

static int
winSetNextWindowViewport(lua_State* L) {
	ImGuiID ID = (ImGuiID)luaL_checkinteger(L, 1);
	ImGui::SetNextWindowViewport(ID);
	return 0;
}

static int
winSetNextWindowSizeConstraints(lua_State *L) {
	float min_w = (float)luaL_checknumber(L, 1);
	float min_h = (float)luaL_checknumber(L, 2);
	float max_w = (float)luaL_checknumber(L, 3);
	float max_h = (float)luaL_checknumber(L, 4);
	ImGui::SetNextWindowSizeConstraints(ImVec2(min_w, min_h), ImVec2(max_w, max_h));
	return 0;
}

static int
winSetNextWindowContentSize(lua_State *L) {
	float x = (float)luaL_checknumber(L, 1);
	float y = (float)luaL_checknumber(L, 2);
	ImGui::SetNextWindowContentSize(ImVec2(x, y));
	return 0;
}

static int
winSetNextWindowCollapsed(lua_State *L) {
	bool collapsed = lua_toboolean(L, 1);
	ImGuiCond cond = get_cond(L, 2);
	ImGui::SetNextWindowCollapsed(collapsed, cond);
	return 0;
}

static int
winSetNextWindowFocus(lua_State *L) {
	ImGui::SetNextWindowFocus();
	return 0;
}

static int
winSetNextWindowBgAlpha(lua_State *L) {
	float alpha = (float)luaL_checknumber(L, 1);
	ImGui::SetNextWindowBgAlpha(alpha);
	return 0;
}

static int
winSetNextWindowDockID(lua_State *L) {
	const char* str_id = luaL_checkstring(L, 1);
	ImGuiCond c = get_cond(L, 2);
	ImGui::SetNextWindowDockID(ImGui::GetID(str_id), c);
	return 0;
}

static int
winGetContentRegionMax(lua_State *L) {
	ImVec2 v = ImGui::GetContentRegionMax();
	lua_pushnumber(L, v.x);
	lua_pushnumber(L, v.y);
	return 2;
}

static int
winGetContentRegionAvail(lua_State *L) {
	ImVec2 v = ImGui::GetContentRegionAvail();
	lua_pushnumber(L, v.x);
	lua_pushnumber(L, v.y);
	return 2;
}

static int
winGetWindowContentRegionMin(lua_State *L) {
	ImVec2 v = ImGui::GetWindowContentRegionMin();
	lua_pushnumber(L, v.x);
	lua_pushnumber(L, v.y);
	return 2;
}

static int
winGetWindowContentRegionMax(lua_State *L) {
	ImVec2 v = ImGui::GetWindowContentRegionMax();
	lua_pushnumber(L, v.x);
	lua_pushnumber(L, v.y);
	return 2;
}

static int
winPushStyleColor(lua_State *L) {
	int stylecol = (int)luaL_checkinteger(L, 1);

	if (stylecol >= 0) {
		float c1 = (float)luaL_checknumber(L, 2);
		float c2 = (float)luaL_checknumber(L, 3);
		float c3 = (float)luaL_checknumber(L, 4);
		float c4 = (float)luaL_optnumber(L, 5, 1.0f);
		ImGui::PushStyleColor(stylecol, ImVec4(c1, c2, c3, c4));
	}
	return 0;
}

static int
winPopStyleColor(lua_State *L) {
	int count = (int)luaL_optinteger(L, 1, 1);
	ImGui::PopStyleColor(count);
	return 0;
}

static int
winPushStyleVar(lua_State *L) {
	int stylevar = (int)luaL_checkinteger(L, 1);
	if (stylevar >= 0) {
		float v1 = (float)luaL_checknumber(L, 2);
		if (lua_isnumber(L, 3)) {
			float v2 = (float)luaL_checknumber(L, 3);
			ImGui::PushStyleVar(stylevar, ImVec2(v1, v2));
		}
		else {
			ImGui::PushStyleVar(stylevar, v1);
		}
	}
	return 0;
}

static int
winPopStyleVar(lua_State *L) {
	int count = (int)luaL_optinteger(L, 1, 1);
	ImGui::PopStyleVar(count);
	return 0;
}

#ifdef _MSC_VER
#pragma endregion IMP_WINDOWS
#endif

// cursor and layout
#ifdef _MSC_VER
#pragma region IMP_CURSOR
#endif

static int
cSeparator(lua_State *L) {
	ImGui::Separator();
	return 0;
}

static int
cSameLine(lua_State *L) {
	float offset_from_start_x = (float)luaL_optnumber(L, 1, 0.0f);
	float spacing = (float)luaL_optnumber(L, 2, -1.0f);
	ImGui::SameLine(offset_from_start_x, spacing);
	return 0;
}

static int
cNewLine(lua_State *L) {
	ImGui::NewLine();
	return 0;
}

static int
cSpacing(lua_State *L) {
	ImGui::Spacing();
	return 0;
}

static int
cDummy(lua_State *L) {
	float x = (float)luaL_checknumber(L, 1);
	float y = (float)luaL_checknumber(L, 2);
	ImGui::Dummy(ImVec2(x, y));
	return 0;
}

static int
cIndent(lua_State *L) {
	float indent_width = (float)luaL_optnumber(L, 1, 0.0f);
	ImGui::Indent(indent_width);
	return 0;
}

static int
cUnindent(lua_State *L) {
	float indent_width = (float)luaL_optnumber(L, 1, 0.0f);
	ImGui::Unindent(indent_width);
	return 0;
}

static int
cBeginGroup(lua_State *L) {
	ImGui::BeginGroup();
	return 0;
}

static int
cEndGroup(lua_State *L) {
	ImGui::EndGroup();
	return 0;
}

static int
cGetCursorPos(lua_State *L) {
	ImVec2 c = ImGui::GetCursorPos();
	lua_pushnumber(L, c.x);
	lua_pushnumber(L, c.y);
	return 2;
}

static int
cSetCursorPos(lua_State *L) {
	if (lua_type(L, 1) == LUA_TNUMBER) {
		ImGui::SetCursorPosX((float)lua_tonumber(L, 1));
	}
	if (lua_type(L, 2) == LUA_TNUMBER) {
		ImGui::SetCursorPosY((float)lua_tonumber(L, 2));
	}
	return 0;
}

static int
cGetCursorStartPos(lua_State *L) {
	ImVec2 c = ImGui::GetCursorStartPos();
	lua_pushnumber(L, c.x);
	lua_pushnumber(L, c.y);
	return 2;
}

static int
cGetCursorScreenPos(lua_State *L) {
	ImVec2 c = ImGui::GetCursorScreenPos();
	lua_pushnumber(L, c.x);
	lua_pushnumber(L, c.y);
	return 2;
}

static int
cSetCursorScreenPos(lua_State *L) {
	float x = (float)luaL_checknumber(L, 1);
	float y = (float)luaL_checknumber(L, 1);
	ImGui::SetCursorScreenPos(ImVec2(x, y));
	return 0;
}

static int
cAlignTextToFramePadding(lua_State *L) {
	ImGui::AlignTextToFramePadding();
	return 0;
}

static int
cGetTextLineHeight(lua_State *L) {
	float v = ImGui::GetTextLineHeight();
	lua_pushnumber(L, v);
	return 1;
}

static int
cGetTextLineHeightWithSpacing(lua_State *L) {
	float v = ImGui::GetTextLineHeightWithSpacing();
	lua_pushnumber(L, v);
	return 1;
}

static int
cGetFrameHeight(lua_State *L) {
	float v = ImGui::GetFrameHeight();
	lua_pushnumber(L, v);
	return 1;
}

static int
cGetFrameHeightWithSpacing(lua_State *L) {
	float v = ImGui::GetFrameHeightWithSpacing();
	lua_pushnumber(L, v);
	return 1;
}

static int
cGetTreeNodeToLabelSpacing(lua_State *L) {
	float v = ImGui::GetTreeNodeToLabelSpacing();
	lua_pushnumber(L, v);
	return 1;
}

static int 
cColumns(lua_State *L) {
	int count = 1;
	const char * id = 0;
	bool border = true;
	if (lua_isinteger(L, 1)) {
		count = (int)lua_tointeger(L, 1);
	}
	if (lua_isstring(L, 2)) {
		id = lua_tostring(L, 2);
	}
	if (lua_isboolean(L, 3)){
		border = lua_toboolean(L, 3);
	}
	ImGui::Columns(count, id, border);
	return 0;
}

static int
cNextColumn(lua_State *L) {
	ImGui::NextColumn();
	return 0;
}

static int
cGetColumnIndex(lua_State *L) {
	lua_Integer index = ImGui::GetColumnIndex();
	lua_pushinteger( L, index + 1 );
	return 1;
}

static int
cGetColumnOffset(lua_State* L) {
	int index = (int)luaL_optinteger(L, 1, 0) - 1;
	float offset = ImGui::GetColumnOffset(index);
	lua_pushnumber(L, offset);
	return 1;
}

static int
cSetColumnOffset(lua_State* L) {
	int index = (int)luaL_checkinteger(L, 1) - 1;
	float offset = (float)luaL_checknumber(L, 2);
	ImGui::SetColumnOffset(index,offset);
	return 0;
}

static int
cGetColumnWidth(lua_State* L) {
	int index = (int)luaL_optinteger(L, 1, 0) - 1;
	float width = ImGui::GetColumnWidth(index);
	lua_pushnumber(L, width);
	return 1;
}

static int
cSetColumnWidth(lua_State* L) {
	int index = (int)luaL_checkinteger(L, 1) - 1;
	float width = (float)luaL_checknumber(L, 2);
	ImGui::SetColumnWidth(index, width);
	return 0;
}

static int
cSetNextItemWidth(lua_State * L) {
	float w = (float)lua_tonumber(L, 1);
	ImGui::SetNextItemWidth(w);
	return 0;
}

static int
cPushItemWidth(lua_State* L) {
	float w = (float)lua_tonumber(L, 1);
	ImGui::PushItemWidth(w);
	return 0;
}

static int
cPopItemWidth(lua_State* L) {
	ImGui::PopItemWidth();
	return 0;
}

static int
cSetMouseCursor(lua_State* L) {
	int mouseCursorType = (int)luaL_optinteger(L, 1, 1);
	ImGui::SetMouseCursor(mouseCursorType);
	return 0;
}

#ifdef _MSC_VER
#pragma endregion IMP_CURSOR
#endif

// Utils
#ifdef _MSC_VER
#pragma region IMP_UTIL
#endif

static int
uSetColorEditOptions(lua_State *L) {
	auto flags = lua_getflags<ImGuiColorEditFlags>(L, 1);
	ImGui::SetColorEditOptions(flags);
	return 0;
}

static int
uPushClipRect(lua_State *L) {
	float left = (float)luaL_checknumber(L, 1);
	float top = (float)luaL_checknumber(L, 2);
	float right = (float)luaL_checknumber(L, 3);
	float bottom = (float)luaL_checknumber(L, 4);
	bool intersect_with_current_clip_rect = lua_toboolean(L, 5);
	ImGui::PushClipRect(ImVec2(left, top), ImVec2(right, bottom), intersect_with_current_clip_rect);
	return 0;
}

static int
uPopClipRect(lua_State *L) {
	ImGui::PopClipRect();
	return 0;
}

static int
uSetItemDefaultFocus(lua_State *L) {
	ImGui::SetItemDefaultFocus();
	return 0;
}

static int
uSetKeyboardFocusHere(lua_State *L) {
	int offset = (int)luaL_optinteger(L, 1, 0);
	ImGui::SetKeyboardFocusHere(offset);
	return 0;
}

static int
uIsItemHovered(lua_State *L) {
	auto flags = lua_getflags<ImGuiHoveredFlags>(L, 1, ImGuiHoveredFlags_None);
	bool change = ImGui::IsItemHovered(flags);
	lua_pushboolean(L, change);
	return 1;
}

static int
uIsItemActive(lua_State *L) {
	bool change = ImGui::IsItemActive();
	lua_pushboolean(L, change);
	return 1;
}

static int
uIsItemFocused(lua_State *L) {
	bool change = ImGui::IsItemFocused();
	lua_pushboolean(L, change);
	return 1;
}

static int
uIsItemClicked(lua_State *L) {
	auto mouse_button = lua_getflags<ImGuiMouseButton>(L, 1, ImGuiMouseButton_Left);
	bool change = ImGui::IsItemClicked(mouse_button);
	lua_pushboolean(L, change);
	return 1;
}

static int
uIsItemVisible(lua_State *L) {
	bool change = ImGui::IsItemVisible();
	lua_pushboolean(L, change);
	return 1;
}

static int
uIsItemEdited(lua_State *L) {
	bool change = ImGui::IsItemEdited();
	lua_pushboolean(L, change);
	return 1;
}

static int
uIsItemActivated(lua_State *L) {
	bool change = ImGui::IsItemActivated();
	lua_pushboolean(L, change);
	return 1;
}

static int
uIsItemDeactivated(lua_State *L) {
	bool change = ImGui::IsItemDeactivated();
	lua_pushboolean(L, change);
	return 1;
}

static int
uIsItemDeactivatedAfterEdit(lua_State *L) {
	bool change = ImGui::IsItemDeactivatedAfterEdit();
	lua_pushboolean(L, change);
	return 1;
}

static int
uIsAnyItemHovered(lua_State *L) {
	bool change = ImGui::IsAnyItemHovered();
	lua_pushboolean(L, change);
	return 1;
}

static int
uIsAnyItemActive(lua_State *L) {
	bool change = ImGui::IsAnyItemActive();
	lua_pushboolean(L, change);
	return 1;
}

static int
uIsAnyItemFocused(lua_State *L) {
	bool change = ImGui::IsAnyItemFocused();
	lua_pushboolean(L, change);
	return 1;
}

static int
uGetItemRectMin(lua_State *L) {
	ImVec2 v = ImGui::GetItemRectMin();
	lua_pushnumber(L, v.x);
	lua_pushnumber(L, v.y);
	return 2;
}

static int
uGetItemRectMax(lua_State *L) {
	ImVec2 v = ImGui::GetItemRectMax();
	lua_pushnumber(L, (lua_Number)v.x);
	lua_pushnumber(L, (lua_Number)v.y);
	return 2;
}

static int
uGetItemRectSize(lua_State *L) {
	ImVec2 v = ImGui::GetItemRectSize();
	lua_pushnumber(L, (lua_Number)v.x);
	lua_pushnumber(L, (lua_Number)v.y);
	return 2;
}

static int
uSetNextItemAllowOverlap(lua_State *L) {
	ImGui::SetNextItemAllowOverlap();
	return 0;
}

static int
uLoadIniSettings(lua_State *L) {
	size_t sz;
	const char * ini = luaL_checklstring(L, 1, &sz);
	ImGui::LoadIniSettingsFromMemory(ini, sz);
	return 0;
}

static int
uSaveIniSettings(lua_State *L) {
	size_t len = 0;
	const char * ini_data = ImGui::SaveIniSettingsToMemory(&len);
	lua_pushlstring(L, ini_data, len);
	ImGuiIO * io = &ImGui::GetIO();
	bool clear_want_save_flag = lua_toboolean(L, 1);
	if (clear_want_save_flag)
		io->WantSaveIniSettings = false;
	return 1;
}

static int
fPush(lua_State *L) {
	lua_Integer id = luaL_checkinteger(L, 1);
	ImFontAtlas* atlas = ImGui::GetIO().Fonts;
	if (id <= 0 || id > atlas->Fonts.Size) {
		luaL_error(L, "Invalid font ID.");
		return 0;
	}
	ImGui::PushFont(atlas->Fonts[int(id - 1)]);
	return 0;
}

static int
fPop(lua_State *L) {
	ImGui::PopFont();
	return 0;
}

static const ImWchar*
GetGlyphRanges(ImFontAtlas* atlas, const char* type) {
	if (strcmp(type, "Default") == 0) {
		return atlas->GetGlyphRangesDefault();
	}
	if (strcmp(type, "Korean") == 0) {
		return atlas->GetGlyphRangesKorean();
	}
	if (strcmp(type, "Japanese") == 0) {
		return atlas->GetGlyphRangesJapanese();
	}
	if (strcmp(type, "ChineseFull") == 0) {
		return atlas->GetGlyphRangesChineseFull();
	}
	if (strcmp(type, "ChineseSimplifiedCommon") == 0) {
		return atlas->GetGlyphRangesChineseSimplifiedCommon();
	}
	if (strcmp(type, "Cyrillic") == 0) {
		return atlas->GetGlyphRangesCyrillic();
	}
	if (strcmp(type, "Thai") == 0) {
		return atlas->GetGlyphRangesThai();
	}
	if (strcmp(type, "Vietnamese") == 0) {
		return atlas->GetGlyphRangesVietnamese();
	}
	return (const ImWchar*)type;
}

static void
fCreateFont(lua_State *L, int idx, ImFontAtlas* atlas, ImFontConfig* config) {
	lua_rawgeti(L, idx, 1);
	lua_rawgeti(L, idx, 2);
	auto ttf = getmemory(L, lua_absindex(L, -2));
	lua_Number size = luaL_checknumber(L, -1);
	const ImWchar* glyphranges = 0;
	if (LUA_TSTRING == lua_rawgeti(L, idx, 3)) {
		glyphranges = GetGlyphRanges(atlas, luaL_checkstring(L, -1));
	}
	atlas->AddFontFromMemoryTTF((void*)ttf.data(), (int)ttf.size(), (float)size, config, glyphranges);
	lua_pop(L, 3);
}

static int
fCreate(lua_State *L) {
	luaL_checktype(L, 1, LUA_TTABLE);
	ImFontAtlas* atlas = ImGui::GetIO().Fonts;
	atlas->Clear();

	ImFontConfig config;
	config.FontDataOwnedByAtlas = false;

	lua_Integer in = luaL_len(L, 1);
	for (lua_Integer i = 1; i <= in; ++i) {
		lua_rawgeti(L, 1, i);
		luaL_checktype(L, -1, LUA_TTABLE);
		config.MergeMode = (i != 1);
		fCreateFont(L, lua_absindex(L, -1), atlas, &config);
		lua_pop(L, 1);
	}

	if (!atlas->Build()) {
		luaL_error(L, "Create font failed.");
		return 0;
	}
	rendererBuildFont(L);
	return 0;
}

static int
uSetNextFrameWantCaptureKeyboard(lua_State * L) {
	bool val = true;
	if (lua_isboolean(L, 1))
		val = lua_toboolean(L, 1);
	ImGui::SetNextFrameWantCaptureKeyboard(val);
	return 0;
}

static int
uSetNextFrameWantCaptureMouse(lua_State * L) {
	bool val = true;
	if (lua_isboolean(L, 1))
		val = lua_toboolean(L, 1);
	ImGui::SetNextFrameWantCaptureMouse(val);
	return 0;
}

static int
uIsMouseDoubleClicked(lua_State * L) {
	auto btn = lua_getflags<ImGuiMouseButton>(L, 1);
	bool clicked = ImGui::IsMouseDoubleClicked(btn);
	lua_pushboolean(L, clicked);
	return 1;
}

static int
uIsKeyPressed(lua_State * L) {
	auto key = lua_getflags<ImGuiKey>(L, 1);
	bool pressed = ImGui::IsKeyPressed(key);
	lua_pushboolean(L, pressed);
	return 1;
}

static int
uPushID(lua_State* L) {
	if (lua_isinteger(L, INDEX_ID)) {
		int id = (int)lua_tointeger(L, INDEX_ID);
		ImGui::PushID(id);
	}
	else {
		const char* id = luaL_checkstring(L, INDEX_ID);
		ImGui::PushID(id);
	}
	return 0;
}

static int
uPopID(lua_State* L) {
	ImGui::PopID();
	return 0;
}

static int
uCalcTextSize(lua_State * L){
	const char * label = luaL_checkstring(L, 1);
	const bool hide_text_after_double_hash = lua_tonumber(L, 2);
	const float wrap_width = (const float)luaL_optnumber(L, 3, -1.0f);
	ImVec2 size = ImGui::CalcTextSize(label, NULL, hide_text_after_double_hash, wrap_width);
	lua_pushnumber(L,size.x);
	lua_pushnumber(L,size.y);
	return 2;
}

static int
uCalcItemWidth(lua_State* L) {
	lua_pushnumber(L, ImGui::CalcItemWidth());
	return 1;
}

static int
cIsMouseDragging(lua_State* L) {
	auto mouse_button = lua_getflags<ImGuiMouseButton>(L, 1, ImGuiMouseButton_Left);
	lua_pushboolean(L, ImGui::IsMouseDragging(mouse_button));
	return 1;
}

static int
cGetMousePos(lua_State* L) {
	auto pos = ImGui::GetMousePos();
	lua_pushnumber(L, pos.x);
	lua_pushnumber(L, pos.y);
	return 2;
}

static int
cSetClipboardText(lua_State* L) {
	const char* text = luaL_checkstring(L, 1);
	ImGui::SetClipboardText(text);
	return 0;
}

#ifdef _MSC_VER
#pragma endregion IMP_UTIL
#endif

// enums
struct enum_pair {
	const char * name;
	lua_Integer value;
};

#define ENUM(prefix, name) { #name, prefix##_##name }

static int
make_flag(lua_State *L) {
	luaL_checktype(L, 1, LUA_TTABLE);
	int i, t;
	lua_Integer r = 0;

	for (i = 1; (t = lua_geti(L, 1, i)) != LUA_TNIL; i++) {
		if (t != LUA_TSTRING)
			luaL_error(L, "Flag name should be string, it's %s", lua_typename(L, t));
		if (lua_gettable(L, lua_upvalueindex(1)) != LUA_TNUMBER) {
			lua_geti(L, 1, i);
			luaL_error(L, "Invalid flag %s.%s", lua_tostring(L, lua_upvalueindex(2)), lua_tostring(L, -1));
		}
		lua_Integer v = lua_tointeger(L, -1);
		lua_pop(L, 1);
		r |= v;
	}
	lua_pushinteger(L, r);
	return 1;
}

static void
flag_gen(lua_State *L, const char *name, struct enum_pair *enums) {
	int i;
	lua_newtable(L);
	for (i = 0; enums[i].name; i++) {
		lua_pushinteger(L, enums[i].value);
		lua_setfield(L, -2, enums[i].name);
	}
	lua_pushstring(L, name);
	lua_pushcclosure(L, make_flag, 2);
	lua_setfield(L, -2, name);
}

static void
enum_gen(lua_State *L, const char *name, struct enum_pair *enums) {
	int i;
	lua_newtable(L);
	for (i = 0; enums[i].name; i++) {
		lua_pushinteger(L, enums[i].value);
		lua_setfield(L, -2, enums[i].name);
	}
	lua_setfield(L, -2, name);
}

#include "imgui_enum.h"

static int
lCreate(lua_State* L) {
	ImGui::CreateContext();
	ImGuiIO& io = ImGui::GetIO();
	io.IniFilename = NULL;
	io.UserData = L;

	io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;
	io.ConfigFlags |= ImGuiConfigFlags_ViewportsEnable;
	io.ConfigFlags |= ImGuiConfigFlags_DockingEnable;
	io.ConfigFlags |= ImGuiConfigFlags_NavNoCaptureKeyboard;
	io.ConfigFlags |= ImGuiConfigFlags_DpiEnableScaleViewports;
	io.ConfigFlags |= ImGuiConfigFlags_DpiEnableScaleFonts;
	io.ConfigViewportsNoTaskBarIcon = true;

	ImGuiStyle& style = ImGui::GetStyle();
	style.WindowRounding = 0.0f;
	style.Colors[ImGuiCol_WindowBg].w = 1.0f;

	window_register(L, 1);
	int width = (int)luaL_checkinteger(L, 2);
	int height = (int)luaL_checkinteger(L, 3);
	void* window = platformCreate(L, width, height);
	if (!window) {
		return luaL_error(L, "Create platform failed");
	}
	if (!rendererCreate()) {
		return luaL_error(L, "Create renderer failed");
	}
	lua_pushlightuserdata(L, window);
	return 1;
}

static int
lNewFrame(lua_State* L) {
	if (!platformNewFrame()) {
		return 0;
	}
	ImGui::NewFrame();
	lua_pushboolean(L, 1);
	return 1;
}

static int
lEndFrame(lua_State* L){
	ImGui::EndFrame();
	return 0;
}

static int
lRender(lua_State* L) {
	ImGui::Render();
	rendererDrawData(ImGui::GetMainViewport());
	ImGui::UpdatePlatformWindows();
	ImGui::RenderPlatformWindowsDefault();
	return 0;
}

static int
lSetWindowPos(lua_State* L) {
	ImGuiPlatformIO& platform_io = ImGui::GetPlatformIO();
	if (!platform_io.Platform_SetWindowPos) {
		return 0;
	}
	auto x = (float)luaL_checkinteger(L, 1);
	auto y = (float)luaL_checkinteger(L, 2);
	platform_io.Platform_SetWindowPos(ImGui::GetMainViewport(), {x, y});
	return 0;
}

static int
lSetWindowTitle(lua_State* L) {
	ImGuiPlatformIO& platform_io = ImGui::GetPlatformIO();
	if (!platform_io.Platform_SetWindowTitle) {
		return 0;
	}
	platform_io.Platform_SetWindowTitle(ImGui::GetMainViewport(), luaL_checkstring(L, 1));
	return 0;
}

#if BX_PLATFORM_WINDOWS
#define bx_malloc_size _msize
#elif BX_PLATFORM_LINUX
#include <malloc.h>
#define bx_malloc_size malloc_usable_size
#elif BX_PLATFORM_OSX
#include <malloc/malloc.h>
#define bx_malloc_size malloc_size
#elif BX_PLATFORM_IOS
#define bx_malloc_size malloc_size
#else
#    error "Unknown PLATFORM!"
#endif

int64_t allocator_memory = 0;

static void* ImGuiAlloc(size_t sz, void* /*user_data*/) {
	void* ptr = malloc(sz);
	if (ptr) {
		allocator_memory += bx_malloc_size(ptr);
	}
	return ptr;
}

static void ImGuiFree(void* ptr, void* /*user_data*/) {
	if (ptr) {
		allocator_memory -= bx_malloc_size(ptr);
	}
	free(ptr);
}

static int
lmemory(lua_State* L) {
	lua_pushinteger(L, allocator_memory);
	return 1;
}

int ImGuiSystemFont(lua_State* L);

extern "C"
#if defined(_WIN32)
__declspec(dllexport)
#endif
int
luaopen_imgui(lua_State *L) {
	luaL_checkversion(L);
	rendererInit(L);
	ImGui::SetAllocatorFunctions(&ImGuiAlloc, &ImGuiFree, NULL);

	luaL_Reg l[] = {
		{ "Create", lCreate },
		{ "Destroy", lDestroy },
		{ "NewFrame", lNewFrame },
		{ "EndFrame", lEndFrame},
		{ "Render", lRender },
		{ "SetWindowPos", lSetWindowPos },
		{ "SetWindowTitle", lSetWindowTitle },
		{ "SetFontProgram", rendererSetFontProgram },
		{ "SetImageProgram", rendererSetImageProgram },
		{ "GetMainViewport", lGetMainViewport },
		{ "InputEvents", lInputEvents },
		{ "memory", lmemory },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);

	luaL_Reg dock[] = {
		{ "Space", dSpace },
		{ "BuilderGetCentralRect", dBuilderGetCentralRect },
		{ NULL, NULL },
	};
	luaL_newlib(L, dock);
	lua_setfield(L, -2, "dock");

	luaL_Reg widgets[] = {
		{ "Button", wButton },
		{ "SmallButton", wSmallButton },
		{ "InvisibleButton", wInvisibleButton },
		{ "ArrowButton", wArrowButton },
		{ "Checkbox", wCheckbox },
		{ "RadioButton", wRadioButton },
		{ "ProgressBar", wProgressBar },
		{ "Bullet", wBullet },
		{ "DragFloat", wDragFloat },
		{ "DragInt", wDragInt },
		{ "SliderFloat", wSliderFloat },
		{ "SliderInt", wSliderInt },
		{ "SliderAngle", wSliderAngle },
		{ "VSliderFloat", wVSliderFloat },
		{ "VSliderInt", wVSliderInt },
		{ "ColorEdit", wColorEdit },
		{ "ColorPicker", wColorPicker },
		{ "ColorButton", wColorButton },
		{ "InputText", wInputText },
		{ "InputFloat", wInputFloat },
		{ "InputInt", wInputInt },
		{ "Text", wText },
		{ "PropertyLabel", wPropertyLabel },
		{ "TextDisabled", wTextDisabled },
		{ "TextWrapped", wTextWrapped },
		{ "LabelText", wLabelText },
		{ "BulletText", wBulletText },
		{ "BeginCombo", wBeginCombo },
		{ "EndCombo", wEndCombo },
		{ "Selectable", wSelectable },
		{ "TreeNode", wTreeNode },
		{ "TreePush", wTreePush },
		{ "TreePop", wTreePop },
		{ "CollapsingHeader", wCollapsingHeader },
		{ "SetNextItemOpen", wSetNextItemOpen },
		{ "PlotLines", wPlotLines },
		{ "PlotHistogram", wPlotHistogram },
		{ "BeginTooltip", wBeginTooltip },
		{ "EndTooltip", wEndTooltip },
		{ "SetTooltip", wSetTooltip },
		{ "BeginMainMenuBar", wBeginMainMenuBar },
		{ "EndMainMenuBar", wEndMainMenuBar },
		{ "BeginMenuBar", wBeginMenuBar },
		{ "EndMenuBar", wEndMenuBar },
		{ "BeginMenu", wBeginMenu },
		{ "EndMenu", wEndMenu },
		{ "MenuItem", wMenuItem },
		{ "BeginListBox", wBeginListBox },
		{ "EndListBox", wEndListBox },
		{ "ListBox", wListBox },
		{ "Image", wImage },
		{ "ImageButton", wImageButton },
		{ "BeginDragDropSource", wBeginDragDropSource },
		{ "EndDragDropSource", wEndDragDropSource },
		{ "SetDragDropPayload", wSetDragDropPayload },
		{ "BeginDragDropTarget", wBeginDragDropTarget },
		{ "EndDragDropTarget", wEndDragDropTarget },
		{ "AcceptDragDropPayload", wAcceptDragDropPayload },
		{ "GetDragDropPayload", wGetDragDropPayload},
		{ "PushTextWrapPos", wPushTextWrapPos },
		{ "PopTextWrapPos", wPopTextWrapPos },
		{ "SelectableInput", wSelectableInput },
		{ NULL, NULL },
	};
	luaL_newlib(L, widgets);
	lua_setfield(L, -2, "widget");

	luaL_Reg cursor[] = {
		{ "Separator", cSeparator },
		{ "SameLine", cSameLine },
		{ "NewLine", cNewLine },
		{ "Spacing", cSpacing },
		{ "Dummy", cDummy },
		{ "Indent", cIndent },
		{ "Unindent", cUnindent },
		{ "BeginGroup", cBeginGroup },
		{ "EndGroup", cEndGroup },
		{ "GetCursorPos", cGetCursorPos },
		{ "SetCursorPos", cSetCursorPos },
		{ "GetCursorStartPos", cGetCursorStartPos },
		{ "GetCursorScreenPos", cGetCursorScreenPos },
		{ "SetCursorScreenPos", cSetCursorScreenPos },
		{ "AlignTextToFramePadding", cAlignTextToFramePadding },
		{ "GetTextLineHeight", cGetTextLineHeight },
		{ "GetTextLineHeightWithSpacing", cGetTextLineHeightWithSpacing },
		{ "GetFrameHeight", cGetFrameHeight },
		{ "GetFrameHeightWithSpacing", cGetFrameHeightWithSpacing },
		{ "GetTreeNodeToLabelSpacing", cGetTreeNodeToLabelSpacing },
		{ "SetNextItemWidth", cSetNextItemWidth },
		{ "PushItemWidth", cPushItemWidth},
		{ "PopItemWidth", cPopItemWidth},
		{ "SetMouseCursor", cSetMouseCursor },
		{ NULL, NULL },
	};

	luaL_newlib(L, cursor);
	lua_setfield(L, -2, "cursor");

	luaL_Reg windows[] = {
		{ "Begin", winBegin },
		{ "End", winEnd },
		{ "BeginDisabled", winBeginDisabled },
		{ "EndDisabled", winEndDisabled },
		{ "BeginChild", winBeginChild },
		{ "EndChild", winEndChild },
		{ "BeginTabBar", winBeginTabBar },
		{ "EndTabBar", winEndTabBar },
		{ "BeginTabItem", winBeginTabItem },
		{ "EndTabItem", winEndTabItem },
		{ "SetTabItemClosed", winSetTabItemClosed },
		{ "OpenPopup", winOpenPopup },
		{ "BeginPopup", winBeginPopup },
		{ "BeginPopupContextItem", winBeginPopupContextItem },
		{ "BeginPopupContextWindow", winBeginPopupContextWindow },
		{ "BeginPopupContextVoid", winBeginPopupContextVoid },
		{ "BeginPopupModal", winBeginPopupModal },
		{ "EndPopup", winEndPopup },
		{ "OpenPopupOnItemClick", winOpenPopupOnItemClick },
		{ "IsPopupOpen", winIsPopupOpen },
		{ "CloseCurrentPopup", winCloseCurrentPopup },
		{ "IsWindowAppearing", winIsWindowAppearing },
		{ "IsWindowCollapsed", winIsWindowCollapsed },
		{ "IsWindowFocused", winIsWindowFocused },
		{ "IsWindowHovered", winIsWindowHovered },
		{ "GetWindowPos", winGetWindowPos },
		{ "GetWindowSize", winGetWindowSize },
		{ "GetScrollX", winGetScrollX },
		{ "GetScrollY", winGetScrollY },
		{ "GetScrollMaxX", winGetScrollMaxX },
		{ "GetScrollMaxY", winGetScrollMaxY },
		{ "SetScrollX", winSetScrollX },
		{ "SetScrollY", winSetScrollY },
		{ "SetScrollHereY", winSetScrollHereY },
		{ "SetScrollFromPosY", winSetScrollFromPosY },
		{ "SetNextWindowPos", winSetNextWindowPos },
		{ "SetNextWindowSize", winSetNextWindowSize },
		{ "SetNextWindowViewport", winSetNextWindowViewport },
		{ "SetNextWindowSizeConstraints", winSetNextWindowSizeConstraints },
		{ "SetNextWindowContentSize", winSetNextWindowContentSize },
		{ "SetNextWindowCollapsed", winSetNextWindowCollapsed },
		{ "SetNextWindowFocus", winSetNextWindowFocus },
		{ "SetNextWindowBgAlpha", winSetNextWindowBgAlpha },
		{ "SetNextWindowDockID", winSetNextWindowDockID },
		{ "GetContentRegionMax", winGetContentRegionMax },
		{ "GetContentRegionAvail", winGetContentRegionAvail },
		{ "GetWindowContentRegionMin", winGetWindowContentRegionMin },
		{ "GetWindowContentRegionMax", winGetWindowContentRegionMax },
		{ "PushStyleColor", winPushStyleColor },
		{ "PopStyleColor", winPopStyleColor },
		{ "PushStyleVar", winPushStyleVar },
		{ "PopStyleVar", winPopStyleVar },
		{ NULL, NULL },
	};

	luaL_newlib(L, windows);
	lua_setfield(L, -2, "windows");

	imgui::table::init(L);

	luaL_Reg util[] = {
		{ "SetColorEditOptions", uSetColorEditOptions },
		{ "PushClipRect", uPushClipRect },
		{ "PopClipRect", uPopClipRect },
		{ "SetItemDefaultFocus", uSetItemDefaultFocus },
		{ "SetKeyboardFocusHere", uSetKeyboardFocusHere },
		{ "IsItemHovered", uIsItemHovered },
		{ "IsItemActive", uIsItemActive },
		{ "IsItemFocused", uIsItemFocused },
		{ "IsItemClicked", uIsItemClicked },
		{ "IsItemVisible", uIsItemVisible },
		{ "IsItemEdited", uIsItemEdited },
		{ "IsItemActivated", uIsItemActivated },
		{ "IsItemDeactivated", uIsItemDeactivated },
		{ "IsItemDeactivatedAfterEdit", uIsItemDeactivatedAfterEdit },
		{ "IsAnyItemHovered", uIsAnyItemHovered },
		{ "IsAnyItemActive", uIsAnyItemActive },
		{ "IsAnyItemFocused", uIsAnyItemFocused },
		{ "GetItemRectMin", uGetItemRectMin },
		{ "GetItemRectMax", uGetItemRectMax },
		{ "GetItemRectSize", uGetItemRectSize },
		{ "SetNextItemAllowOverlap", uSetNextItemAllowOverlap },
		{ "LoadIniSettings", uLoadIniSettings },
		{ "SaveIniSettings", uSaveIniSettings },
		{ "SetNextFrameWantCaptureKeyboard", uSetNextFrameWantCaptureKeyboard },
		{ "SetNextFrameWantCaptureMouse", uSetNextFrameWantCaptureMouse },
		{ "IsMouseDoubleClicked", uIsMouseDoubleClicked},
		{ "IsKeyPressed", uIsKeyPressed},
		{ "PushID",uPushID},
		{ "PopID",uPopID},
		{ "CalcTextSize",uCalcTextSize},
		{ "CalcItemWidth",uCalcItemWidth},
		{ "IsMouseDragging", cIsMouseDragging },
		{ "GetMousePos", cGetMousePos },
		{ "SetClipboardText", cSetClipboardText },
		{ NULL, NULL },
	};

	luaL_newlib(L, util);
	lua_setfield(L, -2, "util");

	luaL_Reg font[] = {
		{ "Push", fPush },
		{ "Pop", fPop },
		{ "Create", fCreate },
		{ "SystemFont", ImGuiSystemFont },
		{ NULL, NULL },
	};

	luaL_newlib(L, font);
	lua_setfield(L, -2, "font");

	luaL_Reg deprecated[] = {
		{ "Columns", cColumns },
		{ "NextColumn", cNextColumn },
		{ "GetColumnIndex", cGetColumnIndex },
		{ "GetColumnOffset", cGetColumnOffset },
		{ "SetColumnOffset", cSetColumnOffset },
		{ "GetColumnWidth", cGetColumnWidth },
		{ "SetColumnWidth", cSetColumnWidth },
		{ NULL, NULL },
	};
	luaL_newlib(L, deprecated);
	lua_setfield(L, -2, "deprecated");

	imgui_enum_init(L);

	return 1;
}
