#define LUA_LIB

extern "C" {
#include <lua.h>
#include <lauxlib.h>
}

#include <bgfx/c99/bgfx.h>
#include <imgui.h>
#include <algorithm>
#include <glm/glm.hpp>
#include <glm/ext/matrix_clip_space.hpp>
#include <cstring>
#include <cstdlib>
#include "bgfx_interface.h"
#include "luabgfx.h"

void init_ime(void* window);
void init_cursor();
void set_cursor(ImGuiMouseCursor cursor);

#define IMGUI_FLAGS_NONE        UINT8_C(0x00)
#define IMGUI_FLAGS_ALPHA_BLEND UINT8_C(0x01)

#ifdef _MSC_VER
#pragma region IMP_IMGUI
#endif

struct context {
	void render(ImDrawData* drawData) {
		const ImGuiIO& io = ImGui::GetIO();
		const float width = io.DisplaySize.x;
		const float height = io.DisplaySize.y;
		const float fb_width = io.DisplaySize.x * drawData->FramebufferScale.x;
		const float fb_height = io.DisplaySize.y * drawData->FramebufferScale.y;

		BGFX(set_view_name)(m_viewId, "ImGui");
		BGFX(set_view_mode)(m_viewId, BGFX_VIEW_MODE_SEQUENTIAL);

		const bgfx_caps_t* caps = BGFX(get_caps)();
		auto ortho = caps->homogeneousDepth
			? glm::orthoLH_NO(0.0f, width, height, 0.0f, 0.0f, 1000.0f)
			: glm::orthoLH_ZO(0.0f, width, height, 0.0f, 0.0f, 1000.0f)
			;
		BGFX(set_view_transform)(m_viewId, NULL, (const void*)&ortho[0]);
		BGFX(set_view_rect)(m_viewId, 0, 0, uint16_t(fb_width), uint16_t(fb_height));

		ImVec2 clip_off = drawData->DisplayPos;
		ImVec2 clip_scale = drawData->FramebufferScale;

		for (int32_t ii = 0, num = drawData->CmdListsCount; ii < num; ++ii) {
			const ImDrawList* drawList = drawData->CmdLists[ii];
			uint32_t numVertices = (uint32_t)drawList->VtxBuffer.size();
			uint32_t numIndices = (uint32_t)drawList->IdxBuffer.size();

			if (numVertices != BGFX(get_avail_transient_vertex_buffer)(numVertices, &m_decl)
				|| numIndices != BGFX(get_avail_transient_index_buffer)(numIndices)) {
				break;
			}

			bgfx_transient_vertex_buffer_t tvb;
			bgfx_transient_index_buffer_t tib;
			BGFX(alloc_transient_vertex_buffer)(&tvb, numVertices, &m_decl);
			BGFX(alloc_transient_index_buffer)(&tib, numIndices);
			ImDrawVert* verts = (ImDrawVert*)tvb.data;
			memcpy(verts, drawList->VtxBuffer.begin(), numVertices * sizeof(ImDrawVert));
			ImDrawIdx* indices = (ImDrawIdx*)tib.data;
			memcpy(indices, drawList->IdxBuffer.begin(), numIndices * sizeof(ImDrawIdx));

			uint32_t offset = 0;
			for (const ImDrawCmd& cmd : drawList->CmdBuffer) {
				if (cmd.UserCallback) {
					cmd.UserCallback(drawList, &cmd);
					offset += cmd.ElemCount;
					continue;
				}
				if (0 == cmd.ElemCount) {
					continue;
				}
				assert(NULL != cmd.TextureId);
				union { ImTextureID ptr; struct { bgfx_texture_handle_t handle; uint8_t flags; uint8_t mip; } s; } texture = { cmd.TextureId };

				ImVec4 clip_rect;
				clip_rect.x = (cmd.ClipRect.x - clip_off.x) * clip_scale.x;
				clip_rect.y = (cmd.ClipRect.y - clip_off.y) * clip_scale.y;
				clip_rect.z = (cmd.ClipRect.z - clip_off.x) * clip_scale.x;
				clip_rect.w = (cmd.ClipRect.w - clip_off.y) * clip_scale.y;

				const uint16_t xx = uint16_t(std::max(clip_rect.x, 0.0f));
				const uint16_t yy = uint16_t(std::max(clip_rect.y, 0.0f));
				BGFX(set_scissor)(xx, yy
					, uint16_t(std::min(clip_rect.z, 65535.0f) - xx)
					, uint16_t(std::min(clip_rect.w, 65535.0f) - yy)
					);

				uint64_t state = 0
					| BGFX_STATE_WRITE_RGB
					| BGFX_STATE_WRITE_A
					| BGFX_STATE_MSAA
					;
				if (IMGUI_FLAGS_ALPHA_BLEND & texture.s.flags) {
					state |= BGFX_STATE_BLEND_FUNC(BGFX_STATE_BLEND_SRC_ALPHA, BGFX_STATE_BLEND_INV_SRC_ALPHA);
				}
				BGFX(set_state)(state, 0);

				BGFX(set_transient_vertex_buffer)(0, &tvb, 0, numVertices);
				BGFX(set_transient_index_buffer)(&tib, offset, cmd.ElemCount);
				if (texture.s.mip) {
					const float lodEnabled[4] = { float(texture.s.mip), 1.0f, 0.0f, 0.0f };
					BGFX(set_uniform)(u_imageLodEnabled, lodEnabled, 1);
					BGFX(submit)(m_viewId, m_imageProgram, 0, false);
				}
				else {
					BGFX(set_texture)(0, s_tex, texture.s.handle, UINT32_MAX);
					BGFX(submit)(m_viewId, m_program, 0, false);
				}
				offset += cmd.ElemCount;
			}
		}
	}

	void create() {
		BGFX(vertex_decl_begin)(&m_decl, BGFX_RENDERER_TYPE_NOOP);
		BGFX(vertex_decl_add)(&m_decl, BGFX_ATTRIB_POSITION, 2, BGFX_ATTRIB_TYPE_FLOAT, false, false);
		BGFX(vertex_decl_add)(&m_decl, BGFX_ATTRIB_TEXCOORD0, 2, BGFX_ATTRIB_TYPE_FLOAT, false, false);
		BGFX(vertex_decl_add)(&m_decl, BGFX_ATTRIB_COLOR0, 4, BGFX_ATTRIB_TYPE_UINT8, true, false);
		BGFX(vertex_decl_end)(&m_decl);
	}

	bgfx_view_id_t        m_viewId;
	bgfx_vertex_decl_t    m_decl;
	bgfx_program_handle_t m_program;
	bgfx_program_handle_t m_imageProgram;
	bgfx_uniform_handle_t s_tex;
	bgfx_uniform_handle_t u_imageLodEnabled;
};

static context s_ctx;

#define INDEX_ID 1
#define INDEX_ARGS 2

struct lua_args {
	lua_State *L;
	bool err;
};


static int
lcreate(lua_State *L) {
	ImGui::CreateContext();
	ImGuiIO& io = ImGui::GetIO();
	io.IniFilename = NULL;
	init_ime(lua_touserdata(L, 1));
	init_cursor();
	s_ctx.create();
	return 0;
}

static int
ldestroy(lua_State *L) {
	ImGui::DestroyContext();
	return 0;
}

static int
lviewId(lua_State *L) {
	s_ctx.m_viewId = (bgfx_view_id_t)luaL_checkinteger(L, 1);
	return 0;
}

static int
lsetDockEnable(lua_State *L) {
	bool enable = lua_toboolean(L, 1);
	ImGuiIO& io = ImGui::GetIO();
	if (enable)
		io.ConfigFlags |= ImGuiConfigFlags_DockingEnable;
	else
		io.ConfigFlags ^= ImGuiConfigFlags_DockingEnable;
	return 0;
}

static int
lprogram(lua_State *L) {
	s_ctx.m_program = bgfx_program_handle_t{ BGFX_LUAHANDLE_ID(PROGRAM, (int)luaL_checkinteger(L, 1)) };
	s_ctx.m_imageProgram = bgfx_program_handle_t{ BGFX_LUAHANDLE_ID(PROGRAM, (int)luaL_checkinteger(L, 2)) };
	s_ctx.u_imageLodEnabled = bgfx_uniform_handle_t{ BGFX_LUAHANDLE_ID(UNIFORM, (int)luaL_checkinteger(L, 3)) };
	s_ctx.s_tex = bgfx_uniform_handle_t{ BGFX_LUAHANDLE_ID(UNIFORM, (int)luaL_checkinteger(L, 4)) };
	return 0;
}

static int
limeHandle(lua_State *L) {
	//TODO:Docking branch remove ImGui::GetIO().ImeWindowHandle
	//lua_pushlightuserdata(L, ImGui::GetIO().ImeWindowHandle);
	lua_pushlightuserdata(L, NULL);
	return 1;
}

static int
lresize(lua_State *L) {
	ImGuiIO& io = ImGui::GetIO();
	float width = (float)luaL_checknumber(L, 1);
	float height = (float)luaL_checknumber(L, 2);
	float xscale = (float)luaL_optnumber(L, 3, 1.0);
	float yscale = (float)luaL_optnumber(L, 4, 1.0);
	io.DisplaySize = ImVec2(width, height);
	io.DisplayFramebufferScale = ImVec2(xscale, yscale);
	return 0;
}

struct lua_imgui_io
{
	
	bool		   inited = false;
	bool        WantCaptureMouse;               // When io.WantCaptureMouse is true, imgui will use the mouse inputs, do not dispatch them to your main game/application (in both cases, always pass on mouse inputs to imgui). (e.g. unclicked mouse is hovering over an imgui window, widget is active, mouse was clicked over an imgui window, etc.).
	bool        WantCaptureKeyboard;            // When io.WantCaptureKeyboard is true, imgui will use the keyboard inputs, do not dispatch them to your main game/application (in both cases, always pass keyboard inputs to imgui). (e.g. InputText active, or an imgui window is focused and navigation is enabled, etc.).
	bool        WantTextInput;                  // Mobile/console: when io.WantTextInput is true, you may display an on-screen keyboard. This is set by ImGui when it wants textual keyboard input to happen (e.g. when a InputText widget is active).
	bool        WantSetMousePos;                // MousePos has been altered, back-end should reposition mouse on next frame. Set only when ImGuiConfigFlags_NavEnableSetMousePos flag is enabled.
	bool        WantSaveIniSettings;            // When manual .ini load/save is active (io.IniFilename == NULL), this will be set to notify your application that you can call SaveIniSettingsToMemory() and save yourself. IMPORTANT: You need to clear io.WantSaveIniSettings yourself.
	bool        NavActive;                      // Directional navigation is currently allowed (will handle ImGuiKey_NavXXX events) = a window is focused and it doesn't use the ImGuiWindowFlags_NoNavInputs flag.
	bool        NavVisible;                     // Directional navigation is visible and allowed (will handle ImGuiKey_NavXXX events).
	float       Framerate;                      // Application framerate estimation, in frame per second. Solely for convenience. Rolling average estimation based on IO.DeltaTime over 120 frames
	int         MetricsRenderVertices;          // Vertices output during last call to Render()
	int         MetricsRenderIndices;           // Indices output during last call to Render() = number of triangles * 3
	int         MetricsRenderWindows;           // Number of visible windows
	int         MetricsActiveWindows;           // Number of active windows
	int         MetricsActiveAllocations;       // Number of active allocations, updated by MemAlloc/MemFree based on current context. May be off if you have multiple imgui contexts.
};

#define sync_io_val(name,inited)  _sync_io_val(L, io_index,#name, io_cache->name, io.name, inited )

static void
_sync_io_val(lua_State * L, int io_index, const char * name, bool& cache_value, bool new_value, bool inited) {
	if (!inited || (cache_value != new_value)) {
		cache_value = new_value;
		lua_pushboolean(L, cache_value);
		lua_setfield(L, io_index, name);
	}
}
static void
_sync_io_val(lua_State * L, int io_index, const char * name, int& cache_value, int new_value, bool inited) {
	if (!inited || (cache_value != new_value)) {
		cache_value = new_value;
		lua_pushinteger(L, cache_value);
		lua_setfield(L, io_index, name);
	}
}
static void
_sync_io_val(lua_State * L, int io_index, const char * name, float& cache_value, float new_value, bool inited) {
	if (!inited || (cache_value != new_value)) {
		cache_value = new_value;
		lua_pushnumber(L, cache_value);
		lua_setfield(L, io_index, name);
	}
}

static void
sync_io(lua_State *L) {
	ImGuiIO& io = ImGui::GetIO();

	int io_cache_index = lua_upvalueindex(2);
	lua_imgui_io * io_cache =  (lua_imgui_io*)lua_touserdata(L, io_cache_index);
	bool inited = io_cache->inited;

	int io_index = lua_upvalueindex(1);
	sync_io_val(WantCaptureMouse, inited);
	sync_io_val(WantCaptureKeyboard, inited);
	sync_io_val(WantTextInput, inited);
	sync_io_val(WantSetMousePos, inited);
	sync_io_val(WantSaveIniSettings, inited);
	sync_io_val(NavActive, inited);
	sync_io_val(NavVisible, inited);
	sync_io_val(Framerate, inited);
	sync_io_val(MetricsRenderVertices, inited);
	sync_io_val(MetricsRenderIndices, inited);
	sync_io_val(MetricsRenderWindows, inited);
	sync_io_val(MetricsActiveWindows, inited);
	sync_io_val(MetricsActiveAllocations, inited);
	if(!inited)
		io_cache->inited = true;
}

static int lshowDockSpace(lua_State * L) {
	static ImGuiDockNodeFlags dockspace_flags = ImGuiDockNodeFlags_None;

	// We are using the ImGuiWindowFlags_NoDocking flag to make the parent window not dockable into,
	// because it would be confusing to have two docking targets within each others.
	ImGuiWindowFlags window_flags = ImGuiWindowFlags_MenuBar | ImGuiWindowFlags_NoDocking;

	ImGuiViewport* viewport = ImGui::GetMainViewport();
	ImGui::SetNextWindowPos(viewport->Pos);
	ImGui::SetNextWindowSize(viewport->Size);
	ImGui::SetNextWindowViewport(viewport->ID);
	ImGui::PushStyleVar(ImGuiStyleVar_WindowRounding, 0.0f);
	ImGui::PushStyleVar(ImGuiStyleVar_WindowBorderSize, 0.0f);
	window_flags |= ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoMove;
	window_flags |= ImGuiWindowFlags_NoBringToFrontOnFocus | ImGuiWindowFlags_NoNavFocus;

	ImGui::PushStyleVar(ImGuiStyleVar_WindowPadding, ImVec2(0.0f, 0.0f));
	bool p_open = true;
	ImGui::Begin("DockSpace Demo", &p_open, window_flags);
	ImGui::PopStyleVar();

	ImGui::PopStyleVar(2);

	ImGuiIO& io = ImGui::GetIO();
	if (io.ConfigFlags & ImGuiConfigFlags_DockingEnable)
	{
		ImGuiID dockspace_id = ImGui::GetID("MyDockSpace");
		ImGui::DockSpace(dockspace_id, ImVec2(0.0f, 0.0f), dockspace_flags);
	}
	ImGui::End();
	return 0;
}

static int
lbeginFrame(lua_State *L) {
	ImGuiIO& io = ImGui::GetIO();
	io.DeltaTime = (float)luaL_checknumber(L, 1);

	ImGuiMouseCursor cursor_type = io.MouseDrawCursor
		? ImGuiMouseCursor_None
		: ImGui::GetMouseCursor();

	ImGui::NewFrame();

	if (io.WantCaptureMouse && !(io.ConfigFlags & ImGuiConfigFlags_NoMouseCursorChange)) {
		set_cursor(cursor_type);
	}

	sync_io(L);
	return 0;
}


static int
lendFrame(lua_State *L) {
	ImGui::Render();
	s_ctx.render(ImGui::GetDrawData());
	return 0;
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

// key, press, state
static int
lkeyState(lua_State *L) {
	int key = (int)luaL_checkinteger(L, 1);
	int press = (int)lua_toboolean(L, 2);
	int state = (int)luaL_checkinteger(L, 3);

	ImGuiIO& io = ImGui::GetIO();

	io.KeyCtrl = (state & 0x01) != 0;
	io.KeyAlt = (state & 0x02) != 0;
	io.KeyShift = (state & 0x04) != 0;
	io.KeySuper = (state & 0x08) != 0;

	if (key >= 0 && key < 256) {
		io.KeysDown[key] = press;
	}
	return 0;
}

static int
lmouseWheel(lua_State *L) {
	ImGuiIO& io = ImGui::GetIO();
	io.MousePos = ImVec2(
		(float)luaL_checknumber(L, 1)/io.DisplayFramebufferScale.x,
		(float)luaL_checknumber(L, 2)/io.DisplayFramebufferScale.y
	);
	io.MouseWheel = (float)luaL_checknumber(L, 3);
	return 0;
}

static int
lmouse(lua_State *L) {
	ImGuiIO& io = ImGui::GetIO();
	io.MousePos = ImVec2(
		(float)luaL_checknumber(L, 1)/io.DisplayFramebufferScale.x,
		(float)luaL_checknumber(L, 2)/io.DisplayFramebufferScale.y
	);
	lua_Integer state = luaL_checkinteger(L, 4);
	if (state != 2) {
		lua_Integer what = luaL_checkinteger(L, 3);
		switch (what) {
		case 1: io.MouseDown[0] = state == 1; break;
		case 2: io.MouseDown[1] = state == 1; break;
		case 3: io.MouseDown[2] = state == 1; break;
		default: break;
		}
	}
	return 0;
}

static int
linputChar(lua_State *L) {
	int c = (int)luaL_checkinteger(L, 1);
	ImGuiIO& io = ImGui::GetIO();
	io.AddInputCharacter(c);
	return 0;
}

#ifdef _MSC_VER
#pragma endregion IMP_IMGUI
#endif

// Widgets bindings
#ifdef _MSC_VER
#pragma region IMP_WIDGET
#endif

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
	ImGuiColorEditFlags flags = (ImGuiColorEditFlags)luaL_optinteger(L, 6, 0);
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
	if (lua_isstring(L, 2)) {
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
	float power = (float)read_field_float(L, "power", 1.0f);
	bool change = false;
	switch (n) {
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
	r = (float)lua_tonumber(L, -1);
	lua_pop(L, 1);
	float width = (float)read_field_checkfloat(L, "width");
	float height = (float)read_field_checkfloat(L, "height");
	float min = (float)read_field_checkfloat(L, "min");
	float max = (float)read_field_checkfloat(L, "max");
	const char * format = read_field_string(L, "format", "%.3f");
	float power = (float)read_field_float(L, "power", 1.0f);
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
	r = (int)lua_tointeger(L, -1);
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
		while (newsize <= (size_t)data->BufTextLen) {
			newsize *= 2;
		}
		data->Buf = (char *)realloc(ebuf->buf, newsize);
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
	ImGui::PushTextWrapPos(0.0f);
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
	case LUA_TBOOLEAN:
		selected = lua_toboolean(L, INDEX_ARGS);
		size.x = (float)luaL_optnumber(L, 3, 0.0f);
		size.y = (float)luaL_optnumber(L, 4, 0.0f);
		flags = (ImGuiSelectableFlags)luaL_optinteger(L, 5, 0);
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
	ImGuiTreeNodeFlags flags = (ImGuiTreeNodeFlags)luaL_optinteger(L, 2, 0);
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
wSetNextItemOpen(lua_State *L) {
	bool is_open = lua_toboolean(L, 1);
	ImGuiCond c = get_cond(L, 2);
	ImGui::SetNextItemOpen(is_open, c);
	return 0;
}

static int
wCollapsingHeader(lua_State *L) {
	const char *label = luaL_checkstring(L, INDEX_ID);
	ImGuiTreeNodeFlags flags = (ImGuiTreeNodeFlags)luaL_optinteger(L, 2, 0);
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
	float width = (float)luaL_optnumber(L, 2, 0);
	float height = (float)luaL_optnumber(L, 3, 0);
	bool change = ImGui::ListBoxHeader(label, ImVec2(width, height));
	lua_pushboolean(L, change);
	return 1;
}

static int
wBeginListBoxN(lua_State *L) {
	const char *label = luaL_checkstring(L, INDEX_ID);
	int count = (int)luaL_checkinteger(L, 2);
	int height_in_items = (int)luaL_optinteger(L, 3, -1);
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
	int n = (int)lua_tointeger(L, 2);
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
	lua_pushinteger(L, idx + 1);
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

inline static ImTextureID
bgfx_to_imgui_texture_id(lua_State*L, int lua_handle) {
	bgfx_texture_handle_t th = { BGFX_LUAHANDLE_ID(TEXTURE, lua_handle) };
	union { struct { bgfx_texture_handle_t handle; uint8_t flags; uint8_t mip; } s; ImTextureID ptr; } texture;
	texture.s.handle = th;
	texture.s.flags = IMGUI_FLAGS_ALPHA_BLEND;
	texture.s.mip = 0;
	return texture.ptr;
}


static int wImage(lua_State *L) {
	int lua_handle = (int)luaL_checkinteger(L, 1);
	ImTextureID tex_id = bgfx_to_imgui_texture_id(L, lua_handle);
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

/**ImageButton( handle,size_x,size_y,
						opt [
							{ uv0={0,0},
							uv1={1,1},
							frame_padding=-1,
							bg_col={0f,0f,0f,0f},
							tint_col={1f,1f,1f,1f},
							flags=0x01,
							mip = 0 }
						] );
**/
static int
wImageButton(lua_State *L) {
	int lua_handle = (int)luaL_checkinteger(L, 1);
	ImTextureID tex_id = bgfx_to_imgui_texture_id(L, lua_handle);
	float size_x = (float)luaL_checknumber(L, 2);
	float size_y = (float)luaL_checknumber(L, 3);
	ImVec2 size = { size_x, size_y };

	ImVec2 uv0 = { 0.0f,0.0f };
	ImVec2 uv1 = { 1.0f,1.0f };
	int frame_padding = -1;
	ImVec4 bg_col = { 0.0f,0.0f,0.0f,0.0f };
	ImVec4 tint_col = { 1.0f,1.0f,1.0f,1.0f };

	if (lua_type(L, 4) == LUA_TTABLE)
	{
		uv0 = read_field_vec2(L, "uv0", uv0, 4);
		uv1 = read_field_vec2(L, "uv1", uv1, 4);
		frame_padding = read_field_int(L, "frame_padding", frame_padding, 4);
		bg_col = read_field_vec4(L, "bg_col", bg_col, 4);
		tint_col = read_field_vec4(L, "tint_col", tint_col, 4);
	}
	bool clicked = ImGui::ImageButton(tex_id, size, uv0, uv1, frame_padding, bg_col, tint_col);
	lua_pushboolean(L, clicked);
	return 1;
}

static int
wBeginDragDropSource(lua_State * L) {
	ImGuiDragDropFlags flag = (ImGuiDragDropFlags)luaL_optinteger(L, 1, 0);
	bool change = ImGui::BeginDragDropSource(flag);
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
	ImGuiDragDropFlags flag;
	if ( is_table_arg ){
		type = read_field_checkstring(L, "type", 1);
		flag = read_field_int(L, "flags", 0, 1);
	}
	else {
		type = luaL_checkstring(L, 1);
		flag = (ImGuiDragDropFlags)luaL_optinteger(L, 2, 0);
	}
	const ImGuiPayload * payload = ImGui::AcceptDragDropPayload(type, flag);
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
winBeginChild(lua_State *L) {
	const char * id = luaL_checkstring(L, INDEX_ID);
	float width = (float)luaL_optnumber(L, 2, 0);
	float height = (float)luaL_optnumber(L, 3, 0);
	bool border = lua_toboolean(L, 4);
	ImGuiWindowFlags flags = (ImGuiWindowFlags)luaL_optinteger(L, 5, 0);
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
	ImGuiTabBarFlags flags = (ImGuiWindowFlags)luaL_optinteger(L, 2, 0);
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
	ImGuiWindowFlags flags = (ImGuiWindowFlags)(luaL_optinteger(L, 2, 0) & 0xffffffff);
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
	args->mouse_button = (int)luaL_optinteger(L, index++, 1);
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
	ImGuiFocusedFlags flags = (ImGuiWindowFlags)luaL_optinteger(L, 1, 0);
	bool v = ImGui::IsWindowFocused(flags);
	lua_pushboolean(L, v);
	return 1;
}

static int
winIsWindowHovered(lua_State *L) {
	ImGuiHoveredFlags flags = (ImGuiWindowFlags)luaL_optinteger(L, 1, 0);
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

static int
winSetWindowFontScale(lua_State* L) {
	luaL_checknumber(L, 1);
	float scale = (float)lua_tonumber(L, 1);
	ImGui::SetWindowFontScale(scale);
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

static int 
cColumns(lua_State *L) {
	int count = 1;
	const char * id = 0;
	bool border = true;
	if (lua_isinteger(L, 1)) {
		count = (int)lua_tointeger(L, 1);
		if (lua_isstring(L, 2)) {
			id = lua_tostring(L, 2);
			if (lua_isboolean(L, 3))
				border = lua_toboolean(L, 3);
		}
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
cSetNextItemWidth(lua_State * L) {
	float w = (float)lua_tonumber(L, 1);
	ImGui::SetNextItemWidth(w);
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
	ImGuiColorEditFlags flags = (ImGuiColorEditFlags)luaL_checkinteger(L, 1);
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
	ImGuiHoveredFlags flags = (ImGuiHoveredFlags)luaL_optinteger(L, 1, 0);
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
	int mouse_button = (int)luaL_optinteger(L, 1, 0);
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
	lua_pushinteger(L, (lua_Integer)v.x);
	lua_pushinteger(L, (lua_Integer)v.y);
	return 2;
}

static int
uGetItemRectMax(lua_State *L) {
	ImVec2 v = ImGui::GetItemRectMax();
	lua_pushinteger(L, (lua_Integer)v.x);
	lua_pushinteger(L, (lua_Integer)v.y);
	return 2;
}

static int
uGetItemRectSize(lua_State *L) {
	ImVec2 v = ImGui::GetItemRectSize();
	lua_pushinteger(L, (lua_Integer)v.x);
	lua_pushinteger(L, (lua_Integer)v.y);
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
CreateFont(lua_State *L, ImFontAtlas* atlas, ImFontConfig* config) {
	size_t ttf_len = 0;
	const char* ttf_buf = 0;
	switch (lua_rawgeti(L, -1, 1)) {
	case LUA_TSTRING:
		ttf_buf = luaL_checklstring(L, -1, &ttf_len);
		break;
	case LUA_TUSERDATA:
		ttf_buf = (const char*)lua_touserdata(L, -1);
		ttf_len = (size_t)*(uint32_t*)ttf_buf;
		ttf_buf += 4;
		break;
	default:
		luaL_checktype(L, -1, LUA_TSTRING);
		break;
	}
	lua_pop(L, 1);

	lua_rawgeti(L, -1, 2);
	lua_Number size = luaL_checknumber(L, -1);
	lua_pop(L, 1);

	const ImWchar* glyphranges = 0;
	if (LUA_TSTRING == lua_rawgeti(L, -1, 3)) {
		glyphranges = GetGlyphRanges(atlas, luaL_checkstring(L, -1));
	}
	lua_pop(L, 1);

	atlas->AddFontFromMemoryTTF((void*)ttf_buf, (int)ttf_len, (float)size, config, glyphranges);
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
		CreateFont(L, atlas, &config);
		lua_pop(L, 1);
	}

	if (!atlas->Build()) {
		luaL_error(L, "Create font failed.");
		return 0;
	}

	uint8_t* data;
	int32_t width;
	int32_t height;
	atlas->GetTexDataAsRGBA32(&data, &width, &height);

	union { ImTextureID ptr; struct { bgfx_texture_handle_t handle; uint8_t flags; uint8_t mip; } s; } texture;
	texture.s.handle = BGFX(create_texture_2d)(
		(uint16_t)width
		, (uint16_t)height
		, false
		, 1
		, BGFX_TEXTURE_FORMAT_BGRA8
		, 0
		, BGFX(copy)(data, width*height * 4)
		);
	texture.s.flags = IMGUI_FLAGS_ALPHA_BLEND;
	texture.s.mip = 0;
	atlas->TexID = texture.ptr;
	return 0;
}

static int
uCaptureKeyboardFromApp(lua_State * L) {
	bool val = true;
	if (lua_isboolean(L, 1))
		val = lua_toboolean(L, 1);
	ImGui::CaptureKeyboardFromApp(val);
	return 0;
}

static int
uCaptureMouseFromApp(lua_State * L) {
	bool val = true;
	if (lua_isboolean(L, 1))
		val = lua_toboolean(L, 1);
	ImGui::CaptureMouseFromApp(val);
	return 0;
}

static int
uIsMouseDoubleClicked(lua_State * L) {
	int btn = (int)luaL_checkinteger(L, 1);
	bool clicked = ImGui::IsMouseDoubleClicked(btn);
	lua_pushboolean(L, clicked);
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

#ifdef _MSC_VER
#pragma endregion IMP_UTIL
#endif

#ifdef _MSC_VER
#pragma region IMP_FLAG
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
	{ "NoClosed", (lua_Integer)1 << 32 },
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
	{ "NoClosed", (lua_Integer)1 << 32 },
	{ NULL, 0 },
};

static struct enum_pair eDragDropFlags[] = {
	ENUM(ImGuiDragDropFlags, SourceNoPreviewTooltip),
	ENUM(ImGuiDragDropFlags, SourceNoDisableHover),
	ENUM(ImGuiDragDropFlags, SourceNoHoldToOpenOthers),
	ENUM(ImGuiDragDropFlags, SourceAllowNullID),
	ENUM(ImGuiDragDropFlags, SourceExtern),
	ENUM(ImGuiDragDropFlags, SourceAutoExpirePayload),
	ENUM(ImGuiDragDropFlags, AcceptBeforeDelivery),
	ENUM(ImGuiDragDropFlags, AcceptNoDrawDefaultRect),
	ENUM(ImGuiDragDropFlags, AcceptNoPreviewTooltip),
	ENUM(ImGuiDragDropFlags, AcceptPeekOnly),
	{ NULL, 0 },
};

#ifdef _MSC_VER
#pragma endregion IMP_FLAG
#endif

#ifdef _MSC_VER
#pragma region IMP_ENUM
#endif

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
#ifdef IMGUI_HAS_DOCK
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

static struct enum_pair eMouseCursor[] = {
	ENUM(ImGuiMouseCursor,None),
	ENUM(ImGuiMouseCursor,Arrow),
	ENUM(ImGuiMouseCursor,TextInput),
	ENUM(ImGuiMouseCursor,ResizeAll),
	ENUM(ImGuiMouseCursor,ResizeNS),
	ENUM(ImGuiMouseCursor,ResizeEW),
	ENUM(ImGuiMouseCursor,ResizeNESW),
	ENUM(ImGuiMouseCursor,ResizeNWSE),
	ENUM(ImGuiMouseCursor,Hand),
	ENUM(ImGuiMouseCursor,COUNT),
	{ NULL, 0 },
};


#ifdef _MSC_VER
#pragma endregion IMP_ENUM
#endif

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
			int value = (int)lua_tointeger(L, -1);
			int i;
			for (i = 0; map[i].name; i++) {
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

static void
push_beginframe( lua_State * L ){
	//set field IO and begin_frame( and IO is its upvalue) 
	lua_newtable(L);

	lua_pushvalue(L, -1);
	lua_setfield(L, -3, "IO");

	size_t io_size = sizeof(lua_imgui_io);
	lua_imgui_io * io_cache =  (lua_imgui_io *)lua_newuserdata(L, io_size);
	io_cache->inited = false;

	lua_pushcclosure(L, lbeginFrame, 2);
}

extern "C"
#if defined(_WIN32)
__declspec(dllexport)
#endif
int
luaopen_imgui(lua_State *L) {
	luaL_checkversion(L);
	init_interface(L);

	luaL_Reg l[] = {
		{ "create", lcreate },
		{ "destroy", ldestroy },
		{ "keymap", lkeymap },
		{ "end_frame", lendFrame },
		{ "key_state", lkeyState },
		{ "input_char", linputChar },
		{ "mouse_wheel", lmouseWheel },
		{ "mouse", lmouse },
		{ "resize", lresize },
		{ "viewid", lviewId },
		{ "program", lprogram },
		{ "ime_handle", limeHandle },
		{ "setDockEnable", lsetDockEnable },
		{ "showDockSpace", lshowDockSpace },
		{ NULL, NULL },
	};

	luaL_newlib(L, l);

	push_beginframe(L);
	lua_setfield(L, -2, "begin_frame");
	
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
		{ "BeginListBoxN", wBeginListBoxN },
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
		{ "PushTextWrapPos", wPushTextWrapPos },
		{ "PopTextWrapPos", wPopTextWrapPos },
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
		{ "Columns", cColumns },
		{ "NextColumn", cNextColumn },
		{ "GetColumnIndex", cGetColumnIndex },
		{ "GetColumnOffset", cGetColumnOffset },
		{ "SetColumnOffset", cSetColumnOffset },
		{ "SetNextItemWidth", cSetNextItemWidth },
		{ "SetMouseCursor", cSetMouseCursor },
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
		{ "SetWindowFontScale", winSetWindowFontScale },
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
		{ "CaptureKeyboardFromApp", uCaptureKeyboardFromApp },
		{ "CaptureMouseFromApp", uCaptureMouseFromApp },
		{ "IsMouseDoubleClicked",uIsMouseDoubleClicked},
		{ "PushID",uPushID},
		{ "PopID",uPopID},
		{ NULL, NULL },
	};

	luaL_newlib(L, util);
	lua_setfield(L, -2, "util");

	luaL_Reg font[] = {
		{ "Push", fPush },
		{ "Pop", fPop },
		{ "Create", fCreate },
		{ NULL, NULL },
	};

	luaL_newlib(L, font);
	lua_setfield(L, -2, "font");
	lua_newtable(L);
	flag_gen(L, "ColorEdit", eColorEditFlags);
	flag_gen(L, "InputText", eInputTextFlags);
	flag_gen(L, "Combo", eComboFlags);
	flag_gen(L, "Selectable", eSelectableFlags);
	flag_gen(L, "TreeNode", eTreeNodeFlags);
	flag_gen(L, "Window", eWindowFlags);
	flag_gen(L, "Focused", eFocusedFlags);
	flag_gen(L, "Hovered", eHoveredFlags);
	flag_gen(L, "TabBar", eTabBarFlags);
	flag_gen(L, "DragDrop", eDragDropFlags);
	lua_setfield(L, -2, "flags");

	lua_newtable(L);
	enum_gen(L, "StyleCol", eStyleCol);
	enum_gen(L, "StyleVar", eStyleVar);
	enum_gen(L, "MouseCursor", eMouseCursor);
	lua_setfield(L, -2, "enum");

	return 1;
}

