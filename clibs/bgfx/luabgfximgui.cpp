#define LUA_LIB

extern "C" {
	#include <lua.h>
	#include <lauxlib.h>
}

#include "imgui/imgui.h"
#include <cstring>
#include <cstdlib>

#define INDEX_ID 1
#define INDEX_ARGS 2

#undef LUA_ENABLE_DOCKING

struct lua_args {
	lua_State *L;
	bool err;
};

static int
lcreate(lua_State *L) {
	float fontSize = luaL_checknumber(L, 1);
	imguiCreate(fontSize);

	ImGuiIO& io = ImGui::GetIO();
	io.IniFilename = NULL;

	return 0;
}

static int
ldestroy(lua_State *L) {
	imguiDestroy();
	return 0;
}

static int
lbeginFrame(lua_State *L) {
	int32_t mx = luaL_checkinteger(L, 1);
	int32_t my = luaL_checkinteger(L, 2);
	int button1 = lua_toboolean(L, 3);
	int button2 = lua_toboolean(L, 4);
	int button3 = lua_toboolean(L, 5);
	int32_t scroll = luaL_checkinteger(L, 6);
	uint16_t width = luaL_checkinteger(L, 7);
	uint16_t height = luaL_checkinteger(L, 8);
	bgfx::ViewId view = luaL_checkinteger(L, 9);
	uint8_t button = 
		(button1 ? IMGUI_MBUT_LEFT : 0) |
		(button2 ? IMGUI_MBUT_RIGHT : 0) |
		(button3 ? IMGUI_MBUT_MIDDLE : 0);
	imguiBeginFrame(mx, my, button, scroll, width, height, -1, view);
	return 0;
}

static int
lendFrame(lua_State *L) {
	imguiEndFrame();
	return 0;
}

static ImGuiCond
get_cond(lua_State *L, int index) {
	int t = lua_type(L, index);
	switch (t) {
	case LUA_TSTRING: {
		const char *cond = lua_tostring(L, index);
		switch(cond[0]) {
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
		return 0;
	default:
		luaL_error(L, "Invalid ImGuiCond type %s", lua_typename(L, t));
	}
	return 0;
}

// Widgets bindings
static int
wButton(lua_State *L) {
	const char * text = luaL_checkstring(L, INDEX_ID);
	int w = luaL_optnumber(L, 2, 0);
	int h = luaL_optnumber(L, 3, 0);
	bool click = ImGui::Button(text, ImVec2(w,h));
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
	int w = luaL_optnumber(L, 2, 0);
	int h = luaL_optnumber(L, 3, 0);
	bool click = ImGui::InvisibleButton(text, ImVec2(w,h));
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
	float c1 = luaL_checknumber(L, 2);
	float c2 = luaL_checknumber(L, 3);
	float c3 = luaL_checknumber(L, 4);
	float c4 = luaL_optnumber(L, 5, 1.0f);
	ImGuiColorEditFlags flags = luaL_optinteger(L, 6, 0);
	float w = luaL_optnumber(L, 7, 0);
	float h = luaL_optnumber(L, 8, 0);
	bool click = ImGui::ColorButton(desc, ImVec4(c1,c2,c3,c4), flags, ImVec2(w,h));
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
	float fraction = luaL_checknumber(L, 1);
	float w = -1;
	float h = 0; 
	const char *overlay = NULL;
	if (lua_isstring(L, 2)) {
		overlay = lua_tostring(L, 2);
	} else {
		w = luaL_optnumber(L, 2, -1);
		h = luaL_optnumber(L, 3, 0);
		if (lua_isstring(L, 4)) {
			overlay = lua_tostring(L, 4);
		}
	}
	ImGui::ProgressBar(fraction, ImVec2(w,h), overlay);
	return 0;
}

static int
wBullet(lua_State *L) {
	ImGui::Bullet();
	return 0;
}

static double
read_field_float(lua_State *L, const char * field, double v) {
	if (lua_getfield(L, INDEX_ARGS, field) == LUA_TNUMBER) {
		v = lua_tonumber(L, -1);
	}
	lua_pop(L, 1);
	return v;
}

static float
read_field_checkfloat(lua_State *L, const char * field) {
	float v;
	if (lua_getfield(L, INDEX_ARGS, field) == LUA_TNUMBER) {
		v = lua_tonumber(L, -1);
	} else {
		v = 0;
		luaL_error(L, "no float %s", field);
	}
	lua_pop(L, 1);
	return v;
}

static int
read_field_int(lua_State *L, const char * field, int v) {
	if (lua_getfield(L, INDEX_ARGS, field) == LUA_TNUMBER) {
		if (!lua_isinteger(L, -1)) {
			luaL_error(L, "Not an integer");
		}
		v = lua_tointeger(L, -1);
	}
	lua_pop(L, 1);
	return v;
}

static int
read_field_checkint(lua_State *L, const char * field) {
	int v;
	if (lua_getfield(L, INDEX_ARGS, field) == LUA_TNUMBER) {
		if (!lua_isinteger(L, -1)) {
			luaL_error(L, "Not an integer");
		}
		v = lua_tointeger(L, -1);
	} else {
		v = 0;
		luaL_error(L, "no int %s", field);
	}
	lua_pop(L, 1);
	return v;
}

static const char *
read_field_string(lua_State *L, const char * field, const char *v) {
	if (lua_getfield(L, INDEX_ARGS, field) == LUA_TSTRING) {
		v = lua_tostring(L, -1);
	}
	lua_pop(L, 1);
	return v;
}

static const char *
read_index_string(lua_State *L, int index, const char *v) {
	if (lua_geti(L, INDEX_ARGS, index) == LUA_TSTRING) {
		v = lua_tostring(L, -1);
	}
	lua_pop(L, 1);
	return v;
}

static bool
read_field_boolean(lua_State *L, const char *field, bool v) {
	if (lua_getfield(L, INDEX_ARGS, field) == LUA_TBOOLEAN) {
		v = (bool)lua_toboolean(L, 1);
	}
	lua_pop(L, 1);
	return v;
}

static bool
drag_float(lua_State *L, const char *label, int n) {
	float v[4];
	int i;
	for (i=0;i<n;i++) {
		if (lua_geti(L, INDEX_ARGS, i+1) != LUA_TNUMBER) {
			luaL_error(L, "Need float [%d]", i+1);
		}
		v[i] = lua_tonumber(L, -1);
		lua_pop(L, 1);
	}
	float speed = read_field_float(L, "speed", 1.0f);
	float min = read_field_float(L, "min", 0.0f);
	float max = read_field_float(L, "max", 0.0f);
	const char * format = read_field_string(L, "format", "%.3f");
	float power = read_field_float(L, "power", 1.0f);
	bool change = false;
	switch(n) {
	case 1:
		change = ImGui::DragFloat(label, v, speed, min, max, format, power);
		break;
	case 2:
		if (read_field_boolean(L, "range", false)) {
			const char *format_max = read_field_string(L, "format_max", NULL);
			change = ImGui::DragFloatRange2(label, v+0, v+1, speed, min, max, format, format_max, power);
		} else {
			change = ImGui::DragFloat2(label, v, speed, min, max, format, power);
		}
		break;
	case 3:
		change = ImGui::DragFloat3(label, v, speed, min, max, format, power);
		break;
	case 4:
		change = ImGui::DragFloat4(label, v, speed, min, max, format, power);
		break;
	}
	if (change) {
		for (i=0;i<n;i++) {
			lua_pushnumber(L, v[i]);
			lua_seti(L, INDEX_ARGS, i+1);
		}
	}
	return change;
}

static bool
drag_int(lua_State *L, const char *label, int n) {
	int v[4];
	int i;
	for (i=0;i<n;i++) {
		if (lua_geti(L, INDEX_ARGS, i+1) != LUA_TNUMBER || !lua_isinteger(L, -1)) {
			luaL_error(L, "Need integer [%d]", i+1);
		}
		v[i] = lua_tointeger(L, -1);
		lua_pop(L, 1);
	}
	float speed = read_field_float(L, "speed", 1.0f);
	int min = read_field_int(L, "min", 0);
	int max = read_field_int(L, "max", 0);
	const char * format = read_field_string(L, "format", "%d");
	bool change = false;
	switch(n) {
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
		for (i=0;i<n;i++) {
			lua_pushinteger(L, v[i]);
			lua_seti(L, INDEX_ARGS, i+1);
		}
	}
	return change;
}

static bool
slider_float(lua_State *L, const char *label, int n) {
	float v[4];
	int i;
	for (i=0;i<n;i++) {
		if (lua_geti(L, INDEX_ARGS, i+1) != LUA_TNUMBER) {
			luaL_error(L, "Need float [%d]", i+1);
		}
		v[i] = lua_tonumber(L, -1);
		lua_pop(L, 1);
	}
	float min = read_field_checkfloat(L, "min");
	float max = read_field_checkfloat(L, "max");
	const char * format = read_field_string(L, "format", "%.3f");
	bool change = false;
	switch(n) {
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
		for (i=0;i<n;i++) {
			lua_pushnumber(L, v[i]);
			lua_seti(L, INDEX_ARGS, i+1);
		}
	}
	return change;
}

static bool
slider_int(lua_State *L, const char *label, int n) {
	int v[4];
	int i;
	for (i=0;i<n;i++) {
		if (lua_geti(L, INDEX_ARGS, i+1) != LUA_TNUMBER || !lua_isinteger(L, -1)) {
			luaL_error(L, "Need integer [%d]", i+1);
		}
		v[i] = lua_tointeger(L, -1);
		lua_pop(L, 1);
	}
	int min = read_field_checkint(L, "min");
	int max = read_field_checkint(L, "max");
	const char * format = read_field_string(L, "format", "%d");
	bool change = false;
	switch(n) {
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
		for (i=0;i<n;i++) {
			lua_pushinteger(L, v[i]);
			lua_seti(L, INDEX_ARGS, i+1);
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
	r = lua_tonumber(L, -1);
	lua_pop(L, 1);
	float min = read_field_float(L, "min", -360.0f);
	float max = read_field_float(L, "max", +360.0f);
	const char * format = read_field_string(L, "format", "%.0f deg");
	float change = ImGui::SliderAngle(label, &r, min, max, format);
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
	r = lua_tonumber(L, -1);
	lua_pop(L, 1);
	float width = read_field_checkfloat(L, "width");
	float height = read_field_checkfloat(L, "height");
	float min = read_field_checkfloat(L, "min");
	float max = read_field_checkfloat(L, "max");
	const char * format = read_field_string(L, "format", "%.3f");
	float power = read_field_float(L, "power", 1.0f);
	float change = ImGui::VSliderFloat(label, ImVec2(width, height), &r, min, max, format, power);
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
	r = lua_tointeger(L, -1);
	lua_pop(L, 1);
	float width = read_field_checkfloat(L, "width");
	float height = read_field_checkfloat(L, "height");
	int min = read_field_checkint(L, "min");
	int max = read_field_checkint(L, "max");
	const char * format = read_field_string(L, "format", "%d");
	float change = ImGui::VSliderInt(label, ImVec2(width, height), &r, min, max, format);
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
	int n = lua_tointeger(L, -1);
	lua_pop(L, 1);
	if (n < 1 || n > 4)
		return luaL_error(L, "Need 1-4 numbers");
	bool change = false;
	// todo: DragScalar/DragScalarN/SliderScalar/SliderScalarN/VSliderScalar
	switch(type) {
	case DRAG_FLOAT:
		change = drag_float(L, label, n);
		break;
	case DRAG_INT:
		change = drag_int(L, label,  n);
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
	int n = lua_tointeger(L, -1);
	lua_pop(L, 1);
	if (n < 3 || n > 4)
		return luaL_error(L, "Need 3-4 numbers");
	ImGuiColorEditFlags flags = read_field_int(L, "flags", 0);
	float v[4];
	int i;
	for (i=0;i<n;i++) {
		if (lua_geti(L, INDEX_ARGS, i+1) != LUA_TNUMBER) {
			luaL_error(L, "Color should be a number");
		}
		v[i] = lua_tonumber(L, -1);
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
		for (i=0;i<n;i++) {
			lua_pushnumber(L, v[i]);
			lua_seti(L, INDEX_ARGS, i+1);
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
	free(ebuf->buf);
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
	struct editbuf *ebuf = (struct editbuf *)lua_newuserdata(L, sizeof(*ebuf));
	ebuf->buf = (char *)malloc(sz);
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
		while (newsize < (size_t)data->BufTextLen) {
			newsize *= 2;
		}
		data->Buf = (char *)realloc(ebuf->buf, newsize);
		if (data->Buf == NULL) {
			data->Buf = ebuf->buf;
			data->BufTextLen = 0;
		} else {
			ebuf->buf = data->Buf;
			ebuf->size = newsize;
		}
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
				data->InsertChars(0, str, str+sz);
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
				data->InsertChars(0, str, str+sz);
				data->CursorPos = sz;
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
		float width = read_field_float(L, "width", 0);
		float height = read_field_float(L, "height", 0);
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
			lua_geti(L, INDEX_ARGS, i+1);
			v[i] = lua_tonumber(L, -1);
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
			for (i=0;i<n;i++) {
				lua_pushnumber(L, v[i]);
				lua_seti(L, INDEX_ARGS, i+1);
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
	for (i=0;i<n;i++) {
		lua_geti(L, INDEX_ARGS, i+1);
		v[i] = lua_tointeger(L, -1);
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
		for (i=0;i<n;i++) {
			lua_pushinteger(L, v[i]);
			lua_seti(L, INDEX_ARGS, i+1);
		}
	}
	return r;
}

static int
wInputFloat(lua_State *L) {
	const char * label = luaL_checkstring(L, INDEX_ID);
	luaL_checktype(L, INDEX_ARGS, LUA_TTABLE);
	lua_len(L, INDEX_ARGS);
	int n = lua_tointeger(L, -1);
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
	int n = lua_tointeger(L, -1);
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
		ImGui::TextUnformatted(text, text+sz);
		break;
	case 4:	// RGB
	case 5: // RGBA
		color[0] = luaL_checknumber(L, 2);
		color[1] = luaL_checknumber(L, 3);
		color[2] = luaL_checknumber(L, 4);
		color[3] = luaL_optnumber(L, 5, 1.0);
		ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(color[0], color[1], color[2], color[3]));
		ImGui::TextUnformatted(text, text+sz);
		ImGui::PopStyleColor();
		break;
	default:
		luaL_error(L, "Invalid args number for Text");
	}
	return 0;
}

static int
wTextDisabled(lua_State *L) {
	size_t sz;
	const char * text = luaL_checklstring(L, 1, &sz);
	ImGui::PushStyleColor(ImGuiCol_Text, ImGui::GetStyle().Colors[ImGuiCol_TextDisabled]);
	ImGui::TextUnformatted(text, text+sz);
	ImGui::PopStyleColor();
	return 0;
}

static int
wTextWrapped(lua_State *L) {
	size_t sz;
	const char * text = luaL_checklstring(L, 1, &sz);
	ImGui::PushTextWrapPos(0.0f);
	ImGui::TextUnformatted(text, text+sz);
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
	ImVec2 size(0,0);
	int t = lua_type(L, INDEX_ARGS);
	switch (t) {
	case LUA_TBOOLEAN:
		selected = lua_toboolean(L, INDEX_ARGS);
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
		size.x = read_field_float(L, "width", 0);
		size.y = read_field_float(L, "height", 0);
		break;
	default:
		return luaL_error(L, "Invalid selected type %s", lua_typename(L, t));
	}
	if (lua_toboolean(L, 3)) {
		flags |= ImGuiSelectableFlags_Disabled;
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
	ImGuiTreeNodeFlags flags = luaL_optinteger(L, 2, 0);
	bool change = ImGui::TreeNodeEx(label, flags);
	lua_pushboolean(L, change);
	return 1;
}

static int
wTreePop(lua_State *L) {
	ImGui::TreePop();
	return 0;
}

static int
wSetNextTreeNodeOpen(lua_State *L) {
	bool is_open = lua_toboolean(L, 1);
	ImGuiCond c = get_cond(L, 2);
	ImGui::SetNextTreeNodeOpen(is_open, c);
	return 0;
}

static int
wCollapsingHeader(lua_State *L) {
	const char *label = luaL_checkstring(L, INDEX_ID);
	ImGuiTreeNodeFlags flags = luaL_optinteger(L, 2, 0);
	bool change = ImGui::CollapsingHeader(label, flags);
	lua_pushboolean(L, change);
	return 1;
}

#define PLOT_LINES 0
#define PLOT_HISTOGRAM 1

static int
get_plot_func(lua_State *L) {
	int n = lua_tointeger(L, 2);
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
	lua_pushinteger(L, idx+1);
	if (lua_pcall(L, 2, 1, 0) != LUA_OK) {
		args->err = true;
		return 0;
	}
	float r = lua_tonumber(L, -1);
	lua_pop(L, 1);
	return r;
}

static void
plot(lua_State *L, int t) {
	const char *label = luaL_checkstring(L, INDEX_ID);
	luaL_checktype(L, INDEX_ARGS, LUA_TTABLE);
	lua_len(L, INDEX_ARGS);
	int n = lua_tointeger(L, -1);
	lua_pop(L, 1);
	int values_offset = read_field_int(L, "offset", 0);
	const char * overlay_text = read_field_string(L, "text", NULL);
	float scale_min = read_field_float(L, "min", FLT_MAX);
	float scale_max = read_field_float(L, "max", FLT_MAX);
	float width = read_field_float(L, "width", 0);
	float height = read_field_float(L, "height", 0);
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
	ImGui::BeginTooltip();
	return 0;
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
	int width = luaL_optinteger(L, 2, 0);
	int height = luaL_optinteger(L, 3, 0);
	bool change = ImGui::ListBoxHeader(label, ImVec2(width, height));
	lua_pushboolean(L, change);
	return 1;
}

static int
wBeginListBoxN(lua_State *L) {
	const char *label = luaL_checkstring(L, INDEX_ID);
	int count = luaL_checkinteger(L, 2);
	int height_in_items = luaL_optinteger(L, 3, -1);
	bool change = ImGui::ListBoxHeader(label, count, height_in_items);
	lua_pushboolean(L, change);
	return 1;
}

static int
wEndListBox(lua_State *L) {
	ImGui::ListBoxFooter();
	return 0;
}

static int
get_listitem_func(lua_State *L) {
	int n = lua_tointeger(L, 2);
	lua_geti(L, 1, n);
	return 1;
}

static bool
get_listitem(void* data, int idx, const char **out_text) {
	struct lua_args *args = (struct lua_args *)data;
	lua_State *L = args->L;
	if (args->err)
		return 0;
	lua_pushcfunction(L, get_listitem_func);
	lua_pushvalue(L, INDEX_ARGS);
	lua_pushinteger(L, idx+1);
	if (lua_pcall(L, 2, 1, 0) != LUA_OK) {
		args->err = true;
		return 0;
	}
	if (lua_type(L, -1) == LUA_TSTRING) {
		*out_text = lua_tostring(L, -1);
		return true;
	}
	lua_pop(L, 1);
	*out_text = NULL;
	return false;
}

static int
wListBox(lua_State *L) {
	const char *label = luaL_checkstring(L, INDEX_ID);
	luaL_checktype(L, INDEX_ARGS, LUA_TTABLE);
	lua_len(L, INDEX_ARGS);
	int n = lua_tointeger(L, -1);
	lua_pop(L, 1);
	int height_in_items = read_field_int(L, "height", -1);
	struct lua_args args = { L, false };
	int current = read_field_int(L, "current", 0) - 1;
	bool change = ImGui::ListBox(label, &current, get_listitem, &args, n, height_in_items);
	if (change) {
		lua_pushinteger(L, current+1);
		lua_setfield(L, INDEX_ARGS, "current");
	}
	lua_pushboolean(L, change);
	return 1;
}

// windows api

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
winBeginChild(lua_State *L) {
	const char * id = luaL_checkstring(L, INDEX_ID);
	float width = luaL_optinteger(L, 2, 0);
	float height = luaL_optinteger(L, 3, 0);
	bool border = lua_toboolean(L, 4);
	ImGuiWindowFlags flags = luaL_optinteger(L, 5, 0);
	bool change = ImGui::BeginChild(id, ImVec2(width, height), border, flags);
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
	ImGuiTabBarFlags flags = luaL_optinteger(L, 2, 0);
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
	const char * id = luaL_checkstring(L, INDEX_ID);
	ImGui::OpenPopup(id);
	return 0;
}

static int
winBeginPopup(lua_State *L) {
	const char * id = luaL_checkstring(L, INDEX_ID);
	ImGuiWindowFlags flags = (ImGuiWindowFlags)(luaL_optinteger(L, 2,0) & 0xffffffff);
	bool change = ImGui::BeginPopup(id, flags);
	lua_pushboolean(L, change);
	return 1;
}

struct popup_args {
	const char *id;
	int mouse_button;
	bool b;
};

static void
get_popup_args(lua_State *L, struct popup_args *args) {
	int index = INDEX_ID;
	int t = lua_type(L, index);
	if (t == LUA_TSTRING || t == LUA_TNIL || t == LUA_TNONE) {
		args->id = lua_tostring(L, index);
		++index;
	}
	args->mouse_button = luaL_optinteger(L, index++, 1);
	if (lua_type(L, index) == LUA_TBOOLEAN) {
		args->b = lua_toboolean(L, index);
	} else {
		args->b = true;
	}
}

static int
winBeginPopupContextItem(lua_State *L) {
	struct popup_args args;
	get_popup_args(L, &args);
	int change = ImGui::BeginPopupContextItem(args.id, args.mouse_button);
	lua_pushboolean(L, change);
	return 1;
}

static int
winBeginPopupContextWindow(lua_State *L) {
	struct popup_args args;
	get_popup_args(L, &args);
	int change = ImGui::BeginPopupContextWindow(args.id, args.mouse_button, args.b);
	lua_pushboolean(L, change);
	return 1;
}

static int
winBeginPopupContextVoid(lua_State *L) {
	struct popup_args args;
	get_popup_args(L, &args);
	int change = ImGui::BeginPopupContextVoid(args.id, args.mouse_button);
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
	struct popup_args args;
	get_popup_args(L, &args);
	int change = ImGui::OpenPopupOnItemClick(args.id, args.mouse_button);
	lua_pushboolean(L, change);
	return 1;
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
	ImGuiFocusedFlags flags = luaL_optinteger(L, 1, 0);
	bool v = ImGui::IsWindowFocused(flags);
	lua_pushboolean(L, v);
	return 1;
}

static int
winIsWindowHovered(lua_State *L) {
	ImGuiHoveredFlags flags = luaL_optinteger(L, 1, 0);
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
	float v = luaL_checknumber(L, 1);
	ImGui::SetScrollX(v);
	return 0;
}

static int
winSetScrollY(lua_State *L) {
	float v = luaL_checknumber(L, 1);
	ImGui::SetScrollY(v);
	return 0;
}

static int
winSetScrollHereY(lua_State *L) {
	float v = luaL_optnumber(L, 1, 0.5);
	ImGui::SetScrollHereY(v);
	return 0;
}

static int
winSetScrollFromPosY(lua_State *L) {
	float local_y = luaL_checknumber(L, 1);
	float v = luaL_optnumber(L, 2, 0.5);
	ImGui::SetScrollFromPosY(local_y, v);
	return 0;
}

static int
winSetNextWindowPos(lua_State *L) {
	float x = luaL_checkinteger(L, 1);
	float y = luaL_checkinteger(L, 2);
	ImGuiCond cond = get_cond(L, 3);
	float px = luaL_optinteger(L, 4, 0);
	float py = luaL_optinteger(L, 5, 0);
	ImGui::SetNextWindowPos(ImVec2(x,y), cond, ImVec2(px,py));
	return 0;
}

static int
winSetNextWindowSize(lua_State *L) {
	float x = luaL_checkinteger(L, 1);
	float y = luaL_checkinteger(L, 2);
	ImGuiCond cond = get_cond(L, 3);
	ImGui::SetNextWindowSize(ImVec2(x,y), cond);
	return 0;
}

static int
winSetNextWindowSizeConstraints(lua_State *L) {
	float min_w = luaL_checkinteger(L, 1);
	float min_h = luaL_checkinteger(L, 2);
	float max_w = luaL_checkinteger(L, 3);
	float max_h = luaL_checkinteger(L, 4);
	ImGui::SetNextWindowSizeConstraints(ImVec2(min_w,min_h), ImVec2(max_w, max_h));
	return 0;
}

static int
winSetNextWindowContentSize(lua_State *L) {
	float x = luaL_checkinteger(L, 1);
	float y = luaL_checkinteger(L, 2);
	ImGui::SetNextWindowContentSize(ImVec2(x,y));
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
	float alpha = luaL_checknumber(L,1);
	ImGui::SetNextWindowBgAlpha(alpha);
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
winGetWindowContentRegionWidth(lua_State *L) {
	float w = ImGui::GetWindowContentRegionWidth();
	lua_pushnumber(L, w);
	return 1;
}

static int
winPushStyleColor(lua_State *L) {
	const char * stylecol = luaL_checkstring(L, 1);
	
	lua_pushstring(L, "StyleCol");
	lua_gettable(L, LUA_REGISTRYINDEX);
	lua_pushstring(L, stylecol);
	lua_gettable(L, -2);
	int flag= luaL_optinteger(L, -1, -1);
	
	if (flag > 0) {
		float c1 = luaL_checknumber(L, 2);
		float c2 = luaL_checknumber(L, 3);
		float c3 = luaL_checknumber(L, 4);
		float c4 = luaL_optnumber(L, 5, 1.0f);
		ImGui::PushStyleColor(flag, ImVec4(c1, c2, c3, c4));
	}
	return 0;
}

static int
winPopStyleColor(lua_State *L) {
	int count = luaL_optinteger(L, 1, 1);
	ImGui::PopStyleColor(count);
	return 0;
}

static int
winPushStyleVar(lua_State *L) {
	const char * stylevar = luaL_checkstring(L, 1);

	lua_pushstring(L, "StyleVar");
	lua_gettable(L, LUA_REGISTRYINDEX);
	lua_pushstring(L, stylevar);
	lua_gettable(L, -2);
	int flag = luaL_optinteger(L, -1, -1);
	
	if (flag >= 0) {
		float v1 = luaL_checknumber(L, 2);
		if (lua_isnumber(L, 3)) {
			float v2 = luaL_checknumber(L, 3);
			ImGui::PushStyleVar(flag, ImVec2(v1,v2));
		}
		else {
			ImGui::PushStyleVar(flag, v1);
		}
	}
	return 0;
}

static int
winPopStyleVar(lua_State *L) {
	int count = luaL_optinteger(L, 1, 1);
	ImGui::PopStyleVar(count);
	return 0;
}



// cursor and layout

static int
cSeparator(lua_State *L) {
	ImGui::Separator();
	return 0;
}

static int
cSameLine(lua_State *L) {
	float offset_from_start_x = luaL_optnumber(L, 1, 0.0f);
	float spacing=luaL_optnumber(L, 2, -1.0f);
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
	float x = luaL_checkinteger(L, 1);
	float y = luaL_checkinteger(L, 2);
	ImGui::Dummy(ImVec2(x,y));
	return 0;
}

static int
cIndent(lua_State *L) {
	ImGui::Indent();
	return 0;
}

static int
cUnindent(lua_State *L) {
	ImGui::Unindent();
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
		ImGui::SetCursorPosX(lua_tonumber(L, 1));
	}
	if (lua_type(L, 2) == LUA_TNUMBER) {
		ImGui::SetCursorPosY(lua_tonumber(L, 2));
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
	float x = luaL_checknumber(L, 1);
	float y = luaL_checknumber(L, 1);
	ImGui::SetCursorScreenPos(ImVec2(x,y));
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
cTreeAdvanceToLabelPos(lua_State *L) {
	ImGui::TreeAdvanceToLabelPos();
	return 0;
}

static int
cGetTreeNodeToLabelSpacing(lua_State *L) {
	float v = ImGui::GetTreeNodeToLabelSpacing();
	lua_pushnumber(L, v);
	return 1;
}

// enums
struct enum_pair {
	const char * name;
	lua_Integer value;
};

#define ENUM(prefix, name) { #name, prefix##_##name }

static int
make_enum(lua_State *L) {
	luaL_checktype(L, 1, LUA_TTABLE);
	int i,t;
	lua_Integer r = 0;

	for (i=1;(t = lua_geti(L, 1, i)) != LUA_TNIL;i++) {
		if (t != LUA_TSTRING)
			luaL_error(L, "Enum name should be string, it's %s", lua_typename(L, t));
		if (lua_gettable(L, lua_upvalueindex(1)) != LUA_TNUMBER) {
			lua_geti(L, 1, i);
			luaL_error(L, "Invalid enum %s.%s", lua_tostring(L, lua_upvalueindex(2)), lua_tostring(L, -1));
		}
		lua_Integer v = lua_tointeger(L, -1);
		lua_pop(L, 1);
		r |= v;
	}
	lua_pushinteger(L, r);
	return 1;
}

static void
enum_gen(lua_State *L, const char *name, struct enum_pair *enums) {
	int i;
	lua_newtable(L);
	for (i=0;enums[i].name;i++) {
		lua_pushinteger(L, enums[i].value);
		lua_setfield(L, -2, enums[i].name);
	}
	lua_pushstring(L, name);
	lua_pushcclosure(L, make_enum, 2);
	lua_setfield(L, -2, name);
}

static void
enum_register(lua_State *L, const char *name, struct enum_pair *enums) {
	int i;
	lua_pushstring(L, name);
	lua_newtable(L);
	for (i = 0; enums[i].name; i++) {
		lua_pushinteger(L, enums[i].value);
		lua_setfield(L, -2, enums[i].name);
	}
	lua_settable(L, LUA_REGISTRYINDEX);
}

// Utils

static int
uSetColorEditOptions(lua_State *L) {
	ImGuiColorEditFlags flags = luaL_checkinteger(L, 1);
	ImGui::SetColorEditOptions(flags);
	return 0;
}

static int
uPushClipRect(lua_State *L) {
	float left = luaL_checkinteger(L, 1);
	float top = luaL_checkinteger(L, 2);
	float right = luaL_checkinteger(L, 3);
	float bottom = luaL_checkinteger(L, 4);
	bool intersect_with_current_clip_rect = lua_toboolean(L, 5);
	ImGui::PushClipRect(ImVec2(left,top), ImVec2(right, bottom), intersect_with_current_clip_rect);
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
	int offset = luaL_optinteger(L, 1, 0);
	ImGui::SetKeyboardFocusHere(offset);
	return 0;
}

static int
uIsItemHovered(lua_State *L) {
	ImGuiHoveredFlags flags = luaL_optinteger(L, 1, 0);
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
	int mouse_button = luaL_optinteger(L, 1, 0);
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
	lua_pushinteger(L, v.x);
	lua_pushinteger(L, v.y);
	return 2;
}

static int
uGetItemRectMax(lua_State *L) {
	ImVec2 v = ImGui::GetItemRectMax();
	lua_pushinteger(L, v.x);
	lua_pushinteger(L, v.y);
	return 2;
}

static int
uGetItemRectSize(lua_State *L) {
	ImVec2 v = ImGui::GetItemRectSize();
	lua_pushinteger(L, v.x);
	lua_pushinteger(L, v.y);
	return 2;
}

static int
uSetItemAllowOverlap(lua_State *L) {
	ImGui::SetItemAllowOverlap();
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
	ImGuiIO& io = ImGui::GetIO();
	if (io.WantSaveIniSettings) {
		size_t sz = 0;
		const char * ini = ImGui::SaveIniSettingsToMemory(&sz);
		io.WantSaveIniSettings = false;
		lua_pushlstring(L, ini, sz);
		return 1;
	} else {
		return 0;
	}
}

// key, press, state
static int
lkeyState(lua_State *L) {
	int key = luaL_checkinteger(L, 1);
	int press = lua_toboolean(L, 2);
	int state = luaL_checkinteger(L, 3);

	ImGuiIO& io = ImGui::GetIO();

	io.KeyCtrl = (state & 0x01) != 0;
	io.KeyAlt = (state & 0x02) != 0;
	io.KeyShift = (state & 0x04) != 0;
	io.KeySuper = (state & 0x08) != 0;

	if (key >=0 && key < 256) {
		io.KeysDown[key] = press;
	}
	return 0;
}

static int
linputChar(lua_State *L) {
	int c = luaL_checkinteger(L, 1);
	ImGuiIO& io = ImGui::GetIO();
	io.AddInputCharacter(c);
	return 0;
}

static struct enum_pair eColorEditFlags[] = {
	ENUM(ImGuiColorEditFlags, NoAlpha),
	ENUM(ImGuiColorEditFlags, NoPicker),
	ENUM(ImGuiColorEditFlags, NoOptions),
	ENUM(ImGuiColorEditFlags, NoSmallPreview),
	ENUM(ImGuiColorEditFlags, NoInputs),
	ENUM(ImGuiColorEditFlags, NoTooltip),
	ENUM(ImGuiColorEditFlags, NoLabel),
	ENUM(ImGuiColorEditFlags, NoSidePreview),
	ENUM(ImGuiColorEditFlags, NoDragDrop),
	ENUM(ImGuiColorEditFlags, AlphaBar),
	ENUM(ImGuiColorEditFlags, AlphaPreview),
	ENUM(ImGuiColorEditFlags, AlphaPreviewHalf),
	ENUM(ImGuiColorEditFlags, HDR),
	ENUM(ImGuiColorEditFlags, DisplayRGB),
	ENUM(ImGuiColorEditFlags, DisplayHSV),
	ENUM(ImGuiColorEditFlags, DisplayHex),
	ENUM(ImGuiColorEditFlags, Uint8),
	ENUM(ImGuiColorEditFlags, Float),
	ENUM(ImGuiColorEditFlags, PickerHueBar),
	ENUM(ImGuiColorEditFlags, PickerHueWheel),
	ENUM(ImGuiColorEditFlags, InputRGB),
	ENUM(ImGuiColorEditFlags, InputHSV),
	{ NULL, 0 },
};

static struct enum_pair eInputTextFlags[] = {
	ENUM(ImGuiInputTextFlags, CharsDecimal),
	ENUM(ImGuiInputTextFlags, CharsHexadecimal),
	ENUM(ImGuiInputTextFlags, CharsUppercase),
	ENUM(ImGuiInputTextFlags, CharsNoBlank),
	ENUM(ImGuiInputTextFlags, AutoSelectAll),
	ENUM(ImGuiInputTextFlags, EnterReturnsTrue),
	ENUM(ImGuiInputTextFlags, CallbackCompletion),
	ENUM(ImGuiInputTextFlags, CallbackHistory),
// Todo : support CallbackAlways
//	ENUM(ImGuiInputTextFlags, CallbackAlways),
	ENUM(ImGuiInputTextFlags, CallbackCharFilter),
	ENUM(ImGuiInputTextFlags, AllowTabInput),
	ENUM(ImGuiInputTextFlags, CtrlEnterForNewLine),
	ENUM(ImGuiInputTextFlags, NoHorizontalScroll),
	ENUM(ImGuiInputTextFlags, AlwaysInsertMode),
	ENUM(ImGuiInputTextFlags, ReadOnly),
	ENUM(ImGuiInputTextFlags, Password),
	ENUM(ImGuiInputTextFlags, NoUndoRedo),
	ENUM(ImGuiInputTextFlags, CharsScientific),
	ENUM(ImGuiInputTextFlags, CallbackResize),
	ENUM(ImGuiInputTextFlags, Multiline),
	{ NULL, 0 },
};

static struct enum_pair eComboFlags[] = {
	ENUM(ImGuiComboFlags, PopupAlignLeft),
	ENUM(ImGuiComboFlags, HeightSmall),
	ENUM(ImGuiComboFlags, HeightRegular),
	ENUM(ImGuiComboFlags, HeightLarge),
	ENUM(ImGuiComboFlags, HeightLargest),
	ENUM(ImGuiComboFlags, NoArrowButton),
	ENUM(ImGuiComboFlags, NoPreview),
	{ NULL, 0 },
};

static struct enum_pair eSelectableFlags[] = {
	ENUM(ImGuiSelectableFlags, DontClosePopups),
	ENUM(ImGuiSelectableFlags, SpanAllColumns),
	ENUM(ImGuiSelectableFlags, AllowDoubleClick),
// Use boolean(disabled) in Selectable(_,_, disabled)
//	ENUM(ImGuiSelectableFlags, Disabled),
	{ NULL, 0 },
};

static struct enum_pair eTreeNodeFlags[] = {
	ENUM(ImGuiTreeNodeFlags, Selected),
	ENUM(ImGuiTreeNodeFlags, Framed),
	ENUM(ImGuiTreeNodeFlags, AllowItemOverlap),
	ENUM(ImGuiTreeNodeFlags, NoTreePushOnOpen),
	ENUM(ImGuiTreeNodeFlags, NoAutoOpenOnLog),
	ENUM(ImGuiTreeNodeFlags, DefaultOpen),
	ENUM(ImGuiTreeNodeFlags, OpenOnDoubleClick),
	ENUM(ImGuiTreeNodeFlags, OpenOnArrow),
	ENUM(ImGuiTreeNodeFlags, Leaf),
	ENUM(ImGuiTreeNodeFlags, Bullet),
	ENUM(ImGuiTreeNodeFlags, FramePadding),
	ENUM(ImGuiTreeNodeFlags, NavLeftJumpsBackHere),
	ENUM(ImGuiTreeNodeFlags, CollapsingHeader),
	{ NULL, 0 },
};

static struct enum_pair eWindowFlags[] = {
	ENUM(ImGuiWindowFlags, NoTitleBar),
	ENUM(ImGuiWindowFlags, NoResize),
	ENUM(ImGuiWindowFlags, NoMove),
	ENUM(ImGuiWindowFlags, NoScrollbar),
	ENUM(ImGuiWindowFlags, NoScrollWithMouse),
	ENUM(ImGuiWindowFlags, NoCollapse),
	ENUM(ImGuiWindowFlags, AlwaysAutoResize),
	ENUM(ImGuiWindowFlags, NoBackground),
	ENUM(ImGuiWindowFlags, NoSavedSettings),
	ENUM(ImGuiWindowFlags, NoMouseInputs),
	ENUM(ImGuiWindowFlags, MenuBar),
	ENUM(ImGuiWindowFlags, HorizontalScrollbar),
	ENUM(ImGuiWindowFlags, NoFocusOnAppearing),
	ENUM(ImGuiWindowFlags, NoBringToFrontOnFocus),
	ENUM(ImGuiWindowFlags, AlwaysVerticalScrollbar),
	ENUM(ImGuiWindowFlags, AlwaysHorizontalScrollbar),
	ENUM(ImGuiWindowFlags, AlwaysUseWindowPadding),
	ENUM(ImGuiWindowFlags, NoNavInputs),
	ENUM(ImGuiWindowFlags, NoNavFocus),
	ENUM(ImGuiWindowFlags, UnsavedDocument),
	ENUM(ImGuiWindowFlags, NoNav),
	ENUM(ImGuiWindowFlags, NoDecoration),
	ENUM(ImGuiWindowFlags, NoInputs),
	{ "NoClosed", (lua_Integer)1<<32 },
	{ NULL, 0 },
};

static struct enum_pair eFocusedFlags[] = {
	ENUM(ImGuiFocusedFlags, ChildWindows),
	ENUM(ImGuiFocusedFlags, RootWindow),
	ENUM(ImGuiFocusedFlags, AnyWindow),
	ENUM(ImGuiFocusedFlags, RootAndChildWindows),
	{ NULL, 0 },
};

static struct enum_pair eHoveredFlags[] = {
	ENUM(ImGuiHoveredFlags, ChildWindows),
	ENUM(ImGuiHoveredFlags, RootWindow),
	ENUM(ImGuiHoveredFlags, AnyWindow),
	ENUM(ImGuiHoveredFlags, AllowWhenBlockedByPopup),
	ENUM(ImGuiHoveredFlags, AllowWhenBlockedByActiveItem),
	ENUM(ImGuiHoveredFlags, AllowWhenOverlapped),
	ENUM(ImGuiHoveredFlags, AllowWhenDisabled),
	ENUM(ImGuiHoveredFlags, RectOnly),
	ENUM(ImGuiHoveredFlags, RootAndChildWindows),
	{ NULL, 0 },
};

static struct enum_pair eTabBarFlags[] = {
	ENUM(ImGuiTabBarFlags, Reorderable),
	ENUM(ImGuiTabBarFlags, AutoSelectNewTabs),
	ENUM(ImGuiTabBarFlags, TabListPopupButton),
	ENUM(ImGuiTabBarFlags, NoCloseWithMiddleMouseButton),
	ENUM(ImGuiTabBarFlags, NoTabListScrollingButtons),
	ENUM(ImGuiTabBarFlags, NoTooltip),
	ENUM(ImGuiTabBarFlags, FittingPolicyResizeDown),
	ENUM(ImGuiTabBarFlags, FittingPolicyScroll),
	{ "NoClosed", (lua_Integer)1<<32 },
	{ NULL, 0 },
};

static struct enum_pair eStyleCol[] = {
	ENUM(ImGuiCol, Text),
	ENUM(ImGuiCol, TextDisabled),
	ENUM(ImGuiCol, WindowBg),              // Background of normal windows
	ENUM(ImGuiCol, ChildBg),               // Background of child windows
	ENUM(ImGuiCol, PopupBg),               // Background of popups, menus, tooltips windows
	ENUM(ImGuiCol, Border),
	ENUM(ImGuiCol, BorderShadow),
	ENUM(ImGuiCol, FrameBg),               // Background of checkbox, radio button, plot, slider, text input
	ENUM(ImGuiCol, FrameBgHovered),
	ENUM(ImGuiCol, FrameBgActive),
	ENUM(ImGuiCol, TitleBg),
	ENUM(ImGuiCol, TitleBgActive),
	ENUM(ImGuiCol, TitleBgCollapsed),
	ENUM(ImGuiCol, MenuBarBg),
	ENUM(ImGuiCol, ScrollbarBg),
	ENUM(ImGuiCol, ScrollbarGrab),
	ENUM(ImGuiCol, ScrollbarGrabHovered),
	ENUM(ImGuiCol, ScrollbarGrabActive),
	ENUM(ImGuiCol, CheckMark),
	ENUM(ImGuiCol, SliderGrab),
	ENUM(ImGuiCol, SliderGrabActive),
	ENUM(ImGuiCol, Button),
	ENUM(ImGuiCol, ButtonHovered),
	ENUM(ImGuiCol, ButtonActive),
	ENUM(ImGuiCol, Header),
	ENUM(ImGuiCol, HeaderHovered),
	ENUM(ImGuiCol, HeaderActive),
	ENUM(ImGuiCol, Separator),
	ENUM(ImGuiCol, SeparatorHovered),
	ENUM(ImGuiCol, SeparatorActive),
	ENUM(ImGuiCol, ResizeGrip),
	ENUM(ImGuiCol, ResizeGripHovered),
	ENUM(ImGuiCol, ResizeGripActive),
	ENUM(ImGuiCol, Tab),
	ENUM(ImGuiCol, TabHovered),
	ENUM(ImGuiCol, TabActive),
	ENUM(ImGuiCol, TabUnfocused),
	ENUM(ImGuiCol, TabUnfocusedActive),
#ifdef LUA_ENABLE_DOCKING
	ENUM(ImGuiCol, DockingPreview),
	ENUM(ImGuiCol, DockingEmptyBg),        // Background color for empty node (e.g. CentralNode with no window docked into it)
#endif
	ENUM(ImGuiCol, PlotLines),
	ENUM(ImGuiCol, PlotLinesHovered),
	ENUM(ImGuiCol, PlotHistogram),
	ENUM(ImGuiCol, PlotHistogramHovered),
	ENUM(ImGuiCol, TextSelectedBg),
	ENUM(ImGuiCol, DragDropTarget),
	ENUM(ImGuiCol, NavHighlight),          // Gamepad/keyboard: current highlighted item
	ENUM(ImGuiCol, NavWindowingHighlight), // Highlight window when using CTRL+TAB
	ENUM(ImGuiCol, NavWindowingDimBg),     // Darken/colorize entire screen behind the CTRL+TAB window list, when active
	ENUM(ImGuiCol, ModalWindowDimBg),      // Darken/colorize entire screen behind a modal window, when one is active
	ENUM(ImGuiCol, COUNT),
	{ NULL, 0 },
};

static struct enum_pair eStyleVar[] = {
	ENUM(ImGuiStyleVar,Alpha),               // float     Alpha
	ENUM(ImGuiStyleVar,WindowPadding),       // ImVec2    WindowPadding
	ENUM(ImGuiStyleVar,WindowRounding),      // float     WindowRounding
	ENUM(ImGuiStyleVar,WindowBorderSize),    // float     WindowBorderSize
	ENUM(ImGuiStyleVar,WindowMinSize),       // ImVec2    WindowMinSize
	ENUM(ImGuiStyleVar,WindowTitleAlign),    // ImVec2    WindowTitleAlign
	ENUM(ImGuiStyleVar,ChildRounding),       // float     ChildRounding
	ENUM(ImGuiStyleVar,ChildBorderSize),     // float     ChildBorderSize
	ENUM(ImGuiStyleVar,PopupRounding),       // float     PopupRounding
	ENUM(ImGuiStyleVar,PopupBorderSize),     // float     PopupBorderSize
	ENUM(ImGuiStyleVar,FramePadding),        // ImVec2    FramePadding
	ENUM(ImGuiStyleVar,FrameRounding),       // float     FrameRounding
	ENUM(ImGuiStyleVar,FrameBorderSize),     // float     FrameBorderSize
	ENUM(ImGuiStyleVar,ItemSpacing),         // ImVec2    ItemSpacing
	ENUM(ImGuiStyleVar,ItemInnerSpacing),    // ImVec2    ItemInnerSpacing
	ENUM(ImGuiStyleVar,IndentSpacing),       // float     IndentSpacing
	ENUM(ImGuiStyleVar,ScrollbarSize),       // float     ScrollbarSize
	ENUM(ImGuiStyleVar,ScrollbarRounding),   // float     ScrollbarRounding
	ENUM(ImGuiStyleVar,GrabMinSize),         // float     GrabMinSize
	ENUM(ImGuiStyleVar,GrabRounding),        // float     GrabRounding
	ENUM(ImGuiStyleVar,TabRounding),         // float     TabRounding
	ENUM(ImGuiStyleVar,ButtonTextAlign),     // ImVec2    ButtonTextAlign
	ENUM(ImGuiStyleVar,SelectableTextAlign), // ImVec2    SelectableTextAlign
	ENUM(ImGuiStyleVar,COUNT),
	{ NULL, 0 },
};

struct keymap {
	const char * name;
	int index;
};

static int
lkeymap(lua_State *L) {
	static struct keymap map[] = {
		{ "Tab", ImGuiKey_Tab },
		{ "Left", ImGuiKey_LeftArrow },
		{ "Right", ImGuiKey_RightArrow },
		{ "Up", ImGuiKey_UpArrow },
		{ "Down", ImGuiKey_DownArrow },
		{ "PageUp", ImGuiKey_PageUp },
		{ "PageDown", ImGuiKey_PageDown },
		{ "Home", ImGuiKey_Home },
		{ "End", ImGuiKey_End },
		{ "Insert", ImGuiKey_Insert },
		{ "Delete", ImGuiKey_Delete },
		{ "Backspace", ImGuiKey_Backspace },
		{ "Space", ImGuiKey_Space },
		{ "Enter", ImGuiKey_Enter },
		{ "Escape", ImGuiKey_Escape },
		{ "A", 'A' },
		{ "C", 'C' },
		{ "V", 'V' },
		{ "X", 'X' },
		{ "Y", 'Y' },
		{ "Z", 'Z' },
		{ NULL, 0 },
	};
	ImGuiIO& io = ImGui::GetIO();
	io.KeyMap[ImGuiKey_A] = 'A';
	io.KeyMap[ImGuiKey_C] = 'C';
	io.KeyMap[ImGuiKey_V] = 'V';
	io.KeyMap[ImGuiKey_X] = 'X';
	io.KeyMap[ImGuiKey_Y] = 'Y';
	io.KeyMap[ImGuiKey_Z] = 'Z';

	luaL_checktype(L, 1, LUA_TTABLE);
	lua_pushnil(L);
	while (lua_next(L, 1) != 0) {
		if (lua_type(L, -2) == LUA_TSTRING && lua_type(L, -1) == LUA_TNUMBER && lua_isinteger(L, -1)) {
			const char * key = lua_tostring(L, -2);
			int value = lua_tointeger(L, -1);
			int i;
			for (i=0;map[i].name;i++) {
				if (strcmp(map[i].name, key) == 0) {
					io.KeyMap[map[i].index] = value;
					break;
				}
			}
		}
		lua_pop(L, 1);
	}
	return 0;
}

extern "C" LUAMOD_API int
luaopen_bgfx_imgui(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "create", lcreate },
		{ "destroy", ldestroy },
		{ "keymap", lkeymap },
		{ "begin_frame", lbeginFrame },
		{ "end_frame", lendFrame },
		{ "key_state", lkeyState },
		{ "input_char", linputChar },
		{ NULL, NULL },
	};

	luaL_newlib(L, l);

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
		{ "TextDisabled", wTextDisabled },
		{ "TextWrapped", wTextWrapped },
		{ "LabelText", wLabelText },
		{ "BulletText", wBulletText },
		{ "BeginCombo", wBeginCombo },
		{ "EndCombo", wEndCombo },
		{ "Selectable", wSelectable },
		{ "TreeNode", wTreeNode },
		{ "TreePop", wTreePop },
		{ "CollapsingHeader", wCollapsingHeader },
		{ "SetNextTreeNodeOpen", wSetNextTreeNodeOpen },
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
		{ "BeginListBoxN", wBeginListBoxN },
		{ "EndListBox", wEndListBox },
		{ "ListBox", wListBox },
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
		{ "TreeAdvanceToLabelPos", cTreeAdvanceToLabelPos },
		{ "GetTreeNodeToLabelSpacing", cGetTreeNodeToLabelSpacing },
		{ NULL, NULL },
	};

	luaL_newlib(L, cursor);
	lua_setfield(L, -2, "cursor");

	luaL_Reg windows[] = {
		{ "Begin", winBegin },
		{ "End", winEnd },
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
		{ "SetNextWindowSizeConstraints", winSetNextWindowSizeConstraints },
		{ "SetNextWindowContentSize", winSetNextWindowContentSize },
		{ "SetNextWindowCollapsed", winSetNextWindowCollapsed },
		{ "SetNextWindowFocus", winSetNextWindowFocus },
		{ "SetNextWindowBgAlpha", winSetNextWindowBgAlpha },
		{ "GetContentRegionMax", winGetContentRegionMax },
		{ "GetContentRegionAvail", winGetContentRegionAvail },
		{ "GetWindowContentRegionMin", winGetWindowContentRegionMin },
		{ "GetWindowContentRegionMax", winGetWindowContentRegionMax },
		{ "GetWindowContentRegionWidth", winGetWindowContentRegionWidth },
		{ "PushStyleColor", winPushStyleColor },
		{ "PopStyleColor", winPopStyleColor },
		{ "PushStyleVar", winPushStyleVar },
		{ "PopStyleVar", winPopStyleVar },
		{ NULL, NULL },
	};

	luaL_newlib(L, windows);
	lua_setfield(L, -2, "windows");

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
		{ "SetItemAllowOverlap", uSetItemAllowOverlap },
		{ "LoadIniSettings", uLoadIniSettings },
		{ "SaveIniSettings", uSaveIniSettings },
		{ NULL, NULL },
	};

	luaL_newlib(L, util);
	lua_setfield(L, -2, "util");

	lua_newtable(L);
	enum_gen(L, "ColorEdit", eColorEditFlags);
	enum_gen(L, "InputText", eInputTextFlags);
	enum_gen(L, "Combo", eComboFlags);
	enum_gen(L, "Selectable", eSelectableFlags);
	enum_gen(L, "TreeNode", eTreeNodeFlags);
	enum_gen(L, "Window", eWindowFlags);
	enum_gen(L, "Focused", eFocusedFlags);
	enum_gen(L, "Hovered", eHoveredFlags);
	enum_gen(L, "TabBar", eTabBarFlags);
	enum_register(L, "StyleCol", eStyleCol);
	enum_register(L, "StyleVar", eStyleVar);

	lua_setfield(L, -2, "flags");

	return 1;
}

