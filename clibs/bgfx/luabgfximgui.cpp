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

static int
lcreate(lua_State *L) {
	float fontSize = luaL_checknumber(L, 1);
	imguiCreate(fontSize);
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

static bool
read_field_boolean(lua_State *L, const char *field) {
	int v = false;
	if (lua_getfield(L, INDEX_ARGS, field) == LUA_TBOOLEAN) {
		v = lua_toboolean(L, 1);
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
		if (read_field_boolean(L, "range")) {
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
		if (read_field_boolean(L, "range")) {
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

/*
    IMGUI_API bool          InputFloat(const char* label, float* v, float step = 0.0f, float step_fast = 0.0f, const char* format = "%.3f", ImGuiInputTextFlags flags = 0);
    IMGUI_API bool          InputFloat2(const char* label, float v[2], const char* format = "%.3f", ImGuiInputTextFlags flags = 0);
    IMGUI_API bool          InputFloat3(const char* label, float v[3], const char* format = "%.3f", ImGuiInputTextFlags flags = 0);
    IMGUI_API bool          InputFloat4(const char* label, float v[4], const char* format = "%.3f", ImGuiInputTextFlags flags = 0);
    IMGUI_API bool          InputInt(const char* label, int* v, int step = 1, int step_fast = 100, ImGuiInputTextFlags flags = 0);
    IMGUI_API bool          InputInt2(const char* label, int v[2], ImGuiInputTextFlags flags = 0);
    IMGUI_API bool          InputInt3(const char* label, int v[3], ImGuiInputTextFlags flags = 0);
    IMGUI_API bool          InputInt4(const char* label, int v[4], ImGuiInputTextFlags flags = 0);
*/

// enums
struct enum_pair {
	const char * name;
	int value;
};

#define ENUM(prefix, name) { #name, prefix##_##name }

static int
make_enum(lua_State *L) {
	luaL_checktype(L, 1, LUA_TTABLE);
	int i,t;
	int r = 0;

	for (i=1;(t = lua_geti(L, 1, i)) != LUA_TNIL;i++) {
		if (t != LUA_TSTRING)
			luaL_error(L, "Enum name should be string, it's %s", lua_typename(L, t));
		if (lua_gettable(L, lua_upvalueindex(1)) != LUA_TNUMBER) {
			lua_geti(L, 1, i);
			luaL_error(L, "Invalid enum %s.%s", lua_tostring(L, lua_upvalueindex(2)), lua_tostring(L, -1));
		}
		int v = lua_tointeger(L, -1);
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

static int
lSetColorEditOptions(lua_State *L) {
	ImGuiColorEditFlags flags = luaL_checkinteger(L, 1);
	ImGui::SetColorEditOptions(flags);
	return 0;
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
		{ "SetColorEditOptions", lSetColorEditOptions },
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
		{ NULL, NULL },
	};
	luaL_newlib(L, widgets);
	lua_setfield(L, -2, "widget");


	lua_newtable(L);
	enum_gen(L, "ColorEditFlags", eColorEditFlags);
	enum_gen(L, "InputTextFlags", eInputTextFlags);
	lua_setfield(L, -2, "enum");

	return 1;
}

