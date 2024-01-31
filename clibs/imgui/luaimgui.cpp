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
#include <bx/platform.h>
#include "backend/imgui_impl_bgfx.h"
#include "imgui_platform.h"
#include "fastio.h"

namespace imgui_lua { void init(lua_State* L); }

static void*
lua_realloc(lua_State *L, void *ptr, size_t osize, size_t nsize) {
	void *ud;
	lua_Alloc allocator = lua_getallocf (L, &ud);
	return allocator(ud, ptr, osize, nsize);
}

#define INDEX_ID 1
#define INDEX_ARGS 2

template <typename Flags>
static Flags lua_getflags(lua_State* L, int idx) {
	return (Flags)luaL_checkinteger(L, idx);
}

template <typename Flags>
static Flags lua_getflags(lua_State* L, int idx, Flags def) {
	return (Flags)luaL_optinteger(L, idx, lua_Integer(def));
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

static int dDockSpace(lua_State* L) {
	const char* str_id = luaL_checkstring(L, 1);
	auto flags = lua_getflags<ImGuiDockNodeFlags>(L, 2);
	float w = (float)luaL_optnumber(L, 3, 0);
	float h = (float)luaL_optnumber(L, 4, 0);
	ImGui::DockSpace(ImGui::GetID(str_id), ImVec2(w, h), flags);
	return 0;
}

static int dDockBuilderGetCentralRect(lua_State * L) {
	const char* str_id = luaL_checkstring(L, 1);
	ImGuiDockNode* central_node = ImGui::DockBuilderGetCentralNode(ImGui::GetID(str_id));
	lua_pushnumber(L, central_node->Pos.x);
	lua_pushnumber(L, central_node->Pos.y);
	lua_pushnumber(L, central_node->Size.x);
	lua_pushnumber(L, central_node->Size.y);
	return 4;
}

static int ClipperRelease(lua_State* L) {
	ImGuiListClipper* clipper = (ImGuiListClipper*)luaL_testudata(L, 1, "IMGUI_CLIPPER");
	clipper->~ImGuiListClipper();
	return 0;
}

static int ClipperEnd(lua_State* L) {
	ImGuiListClipper* clipper = (ImGuiListClipper*)lua_touserdata(L, lua_upvalueindex(1));
	clipper->End();
	return 0;
}

static int ClipperStep(lua_State* L) {
	ImGuiListClipper* clipper = (ImGuiListClipper*)lua_touserdata(L, lua_upvalueindex(1));
	bool ok = clipper->Step();
	if (!ok) {
		return 0;
	}
	lua_pushinteger(L, (lua_Integer)clipper->DisplayStart + 1);
	lua_pushinteger(L, (lua_Integer)clipper->DisplayEnd);
	return 2;
}

static int ClipperBegin(lua_State* L) {
	ImGuiListClipper* clipper = (ImGuiListClipper*)lua_touserdata(L, lua_upvalueindex(1));
	int n = (int)luaL_checkinteger(L, 1);
	float height = (float)luaL_optnumber(L, 2, -1.0f);
	clipper->Begin(n, height);
	lua_pushvalue(L, lua_upvalueindex(2));
	lua_pushnil(L);
	lua_pushnil(L);
	lua_pushvalue(L, lua_upvalueindex(3));
	return 4;
}

static int ListClipper(lua_State* L) {
	ImGuiListClipper* clipper = (ImGuiListClipper*)lua_newuserdatauv(L, sizeof(ImGuiListClipper), 0);
	new (clipper) ImGuiListClipper;
	if (luaL_newmetatable(L, "IMGUI_CLIPPER")) {
		lua_pushcfunction(L, ClipperRelease);
		lua_setfield(L, -2, "__gc");
	}
	lua_setmetatable(L, -2);

	lua_pushvalue(L, -1);
	lua_pushcclosure(L, ClipperStep, 1);

	lua_newtable(L);
	lua_pushvalue(L, -3);
	lua_pushcclosure(L, ClipperEnd, 1);
	lua_setfield(L, -2, "__close");
	lua_pushvalue(L, -1);
	lua_setmetatable(L, -2);
	
	lua_pushcclosure(L, ClipperBegin, 3);
	return 1;
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

static const ImWchar* GetGlyphRanges(ImFontAtlas* atlas, const char* type) {
	if (!type) {
		return nullptr;
	}
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

static int lInitFont(lua_State *L) {
	luaL_checktype(L, 1, LUA_TTABLE);
	ImFontAtlas* atlas = ImGui::GetIO().Fonts;
	atlas->Clear();

	lua_Integer n = luaL_len(L, 1);
	for (lua_Integer i = 1; i <= n; ++i) {
		lua_rawgeti(L, 1, i);
		luaL_checktype(L, -1, LUA_TTABLE);
		int idx = lua_absindex(L, -1);
		lua_getfield(L, idx, "FontData");
		auto ttf = getmemory(L, lua_absindex(L, -1));
		ImFontConfig config;
		config.MergeMode = (i != 1);
		config.FontData = (void*)ttf.data();
		config.FontDataSize = (int)ttf.size();
		config.FontDataOwnedByAtlas = false;
		config.SizePixels = read_field_checkfloat(L, "SizePixels", idx);
		config.GlyphRanges = GetGlyphRanges(atlas, read_field_string(L, "GlyphRanges", nullptr, idx));
		atlas->AddFont(&config);
		lua_pop(L, 2);
	}

	if (!atlas->Build()) {
		luaL_error(L, "Create font failed.");
		return 0;
	}
	ImGui_ImplBgfx_CreateFontsTexture();
	return 0;
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

// TODO: support ImGuiInputTextFlags_CallbackAlways
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
	if (hint) {
		change = ImGui::InputTextWithHint(label, hint, ebuf->buf, ebuf->size, flags, edit_callback, ebuf);
	} else {
		change = ImGui::InputText(label, ebuf->buf, ebuf->size, flags, edit_callback, ebuf);
	}
	if (lua_gettop(L) != top) {
		lua_error(L);
	}
	lua_pushboolean(L, change);
	return 1;
}

static int
wInputTextMultiline(lua_State *L) {
	const char * label = luaL_checkstring(L, INDEX_ID);
	luaL_checktype(L, INDEX_ARGS, LUA_TTABLE);
	ImGuiInputTextFlags flags = read_field_int(L, "flags", 0);
	int t = lua_getfield(L, INDEX_ARGS, "text");
	if (t == LUA_TSTRING || t == LUA_TNIL) {
		create_new_editbuf(L);
		lua_pushvalue(L, -1);
		lua_setfield(L, INDEX_ARGS, "text");
	}
	struct editbuf * ebuf = (struct editbuf *)luaL_checkudata(L, -1, "IMGUI_EDITBUF");
	ebuf->L = L;
	int top = lua_gettop(L);
	float width = (float)read_field_float(L, "width", 0);
	float height = (float)read_field_float(L, "height", 0);
	flags |= ImGuiInputTextFlags_CallbackResize;
	bool change = ImGui::InputTextMultiline(label, ebuf->buf, ebuf->size, ImVec2(width, height), flags, edit_callback, ebuf);
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
lCreateContext(lua_State* L) {
	ImGui::CreateContext();
	ImGuiIO& io = ImGui::GetIO();
	io.IniFilename = NULL;
	io.UserData = L;
	io.ConfigViewportsNoTaskBarIcon = true;
	ImGuiStyle& style = ImGui::GetStyle();
	style.WindowRounding = 0.0f;
	style.Colors[ImGuiCol_WindowBg].w = 1.0f;
	return 0;
}

static int
lDestroyContext(lua_State *L) {
	ImGui::DestroyContext();
	return 0;
}

static int
lInitPlatform(lua_State* L) {
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	void* window = lua_touserdata(L, 1);
	platformInit(window);
	return 0;
}

static int
lInitRender(lua_State* L) {
	RendererInitArgs initargs;
	initargs.fontProg = read_field_checkint(L, "fontProg", 1);
	initargs.imageProg = read_field_checkint(L, "imageProg", 1);
	initargs.fontUniform = read_field_checkint(L, "fontUniform", 1);
	initargs.imageUniform = read_field_checkint(L, "imageUniform", 1);
	
	if (lua_getfield(L, 1, "viewIdPool") == LUA_TTABLE) {
		lua_Integer n = luaL_len(L, -1);
		initargs.viewIdPool.reserve((size_t)n);
		for (lua_Integer i = 1; i <= n; ++i) {
			if (LUA_TNUMBER == lua_geti(L, -1, i)) {
				initargs.viewIdPool.push_back((int)luaL_checkinteger(L, -1));
			}
			lua_pop(L, 1);
		}
	}
	else {
		luaL_error(L, "no table viewIdPool");
	}
	lua_pop(L, 1);

	if (!ImGui_ImplBgfx_Init(initargs)) {
		return luaL_error(L, "Create renderer failed");
	}
	return 0;
}

static int
lDestroyPlatform(lua_State* L) {
	platformShutdown();
	return 0;
}

static int
lDestroyRenderer(lua_State* L) {
	ImGui_ImplBgfx_Shutdown();
	return 0;
}

static int
lNewFrame(lua_State* L) {
	platformNewFrame();
	ImGui::NewFrame();
	return 0;
}

static int
lEndFrame(lua_State* L){
	ImGui::EndFrame();
	return 0;
}

static int
lRender(lua_State* L) {
	ImGui::Render();
	ImGui_ImplBgfx_RenderDrawData(ImGui::GetMainViewport());
	ImGui::UpdatePlatformWindows();
	ImGui::RenderPlatformWindowsDefault();
	return 0;
}

static int
ioAddMouseButtonEvent(lua_State* L) {
	ImGuiIO& io = ImGui::GetIO();
	int button = (int)luaL_checkinteger(L, 1);
	bool down = !!lua_toboolean(L, 2);
	io.AddMouseButtonEvent(button, down);
	return 0;
}

static int
ioAddMouseWheelEvent(lua_State* L) {
	ImGuiIO& io = ImGui::GetIO();
	float x = (float)luaL_checknumber(L, 1);
	float y = (float)luaL_checknumber(L, 2);
	io.AddMouseWheelEvent(x, y);
	return 0;
}

static int
ioAddKeyEvent(lua_State* L) {
	ImGuiIO& io = ImGui::GetIO();
	auto key = (ImGuiKey)luaL_checkinteger(L, 1);
	bool down = !!lua_toboolean(L, 2);
	io.AddKeyEvent(key, down);
	return 0;
}

static int
ioAddInputCharacter(lua_State* L) {
	ImGuiIO& io = ImGui::GetIO();
	auto c = (unsigned int)luaL_checkinteger(L, 1);
	io.AddInputCharacter(c);
	return 0;
}

static int
ioAddInputCharacterUTF16(lua_State* L) {
	ImGuiIO& io = ImGui::GetIO();
	auto c = (ImWchar16)luaL_checkinteger(L, 1);
	io.AddInputCharacterUTF16(c);
	return 0;
}

static int
ioAddFocusEvent(lua_State* L) {
	ImGuiIO& io = ImGui::GetIO();
	bool focused = !!lua_toboolean(L, 1);
	io.AddFocusEvent(focused);
	return 0;
}

static int
ioSetterConfigFlags(lua_State* L) {
	ImGuiIO& io = ImGui::GetIO();
	io.ConfigFlags = lua_getflags<ImGuiConfigFlags>(L, 1, ImGuiPopupFlags_None);
	return 0;
}

static int
ioGetterWantCaptureMouse(lua_State* L) {
	ImGuiIO& io = ImGui::GetIO();
	lua_pushboolean(L, io.WantCaptureMouse);
	return 1;
}

static int
ioGetterWantCaptureKeyboard(lua_State* L) {
	ImGuiIO& io = ImGui::GetIO();
	lua_pushboolean(L, io.WantCaptureKeyboard);
	return 1;
}

static int
ioSetter(lua_State* L) {
	lua_pushvalue(L, 2);
	if (LUA_TNIL == lua_gettable(L, lua_upvalueindex(1))) {
		return luaL_error(L, "io.%s is invalid", lua_tostring(L, 2));
	}
	lua_pushvalue(L, 3);
	lua_call(L, 1, 0);
	return 0;
}

static int
ioGetter(lua_State* L) {
	lua_pushvalue(L, 2);
	if (LUA_TNIL == lua_gettable(L, lua_upvalueindex(1))) {
		return luaL_error(L, "io.%s is invalid", lua_tostring(L, 2));
	}
	lua_call(L, 0, 1);
	return 1;
}

#if BX_PLATFORM_WINDOWS
#define bx_malloc_size _msize
#elif BX_PLATFORM_LINUX || BX_PLATFORM_ANDROID
#include <malloc.h>
#define bx_malloc_size malloc_usable_size
#elif BX_PLATFORM_OSX
#include <malloc/malloc.h>
#define bx_malloc_size malloc_size
#elif BX_PLATFORM_IOS
#include <malloc/malloc.h>
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

static int util_memory(lua_State* L) {
	lua_pushinteger(L, allocator_memory);
	return 1;
}

extern "C"
#if defined(_WIN32)
__declspec(dllexport)
#endif
int
luaopen_imgui(lua_State *L) {
	luaL_checkversion(L);
	ImGui::SetAllocatorFunctions(&ImGuiAlloc, &ImGuiFree, NULL);

	luaL_Reg l[] = {
		{ "CreateContext", lCreateContext },
		{ "DestroyContext", lDestroyContext },
		{ "InitPlatform", lInitPlatform },
		{ "InitRender", lInitRender },
		{ "DestroyPlatform", lDestroyPlatform },
		{ "DestroyRenderer", lDestroyRenderer },
		{ "NewFrame", lNewFrame },
		{ "EndFrame", lEndFrame },
		{ "Render", lRender },
		{ "GetMainViewport", lGetMainViewport },
		{ "InitFont", lInitFont },
		{ "InputText", wInputText },
		{ "InputTextMultiline", wInputTextMultiline },
		{ "InputFloat", wInputFloat },
		{ "InputInt", wInputInt },
		{ "DockSpace", dDockSpace },
		{ "DockBuilderGetCentralRect", dDockBuilderGetCentralRect },
		{ "ListClipper", ListClipper },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);

	luaL_Reg util[] = {
		{ "memory", util_memory },
		{ NULL, NULL },
	};
	luaL_newlib(L, util);
	lua_setfield(L, -2, "util");

	imgui_lua::init(L);

	luaL_Reg io[] = {
		{ "AddMouseButtonEvent", ioAddMouseButtonEvent },
		{ "AddMouseWheelEvent", ioAddMouseWheelEvent },
		{ "AddKeyEvent", ioAddKeyEvent },
		{ "AddInputCharacter", ioAddInputCharacter },
		{ "AddInputCharacterUTF16", ioAddInputCharacterUTF16 },
		{ "AddFocusEvent", ioAddFocusEvent },
		{ NULL, NULL },
	};
	luaL_Reg io_setter[] = {
		{ "ConfigFlags", ioSetterConfigFlags },
		{ NULL, NULL },
	};
	luaL_Reg io_getter[] = {
		{ "WantCaptureMouse", ioGetterWantCaptureMouse },
		{ "WantCaptureKeyboard", ioGetterWantCaptureKeyboard },
		{ NULL, NULL },
	};
	luaL_newlib(L, io);
	lua_newtable(L);
	luaL_newlib(L, io_setter);
	lua_pushcclosure(L, ioSetter, 1);
	lua_setfield(L, -2, "__newindex");
	luaL_newlib(L, io_getter);
	lua_pushcclosure(L, ioGetter, 1);
	lua_setfield(L, -2, "__index");
	lua_setmetatable(L, -2);
	lua_setfield(L, -2, "io");

	imgui_enum_init(L);
	return 1;
}
