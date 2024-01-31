#include <lua.hpp>
#include <imgui.h>
#include <imgui_internal.h>
#include <cstdint>

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

static const char *
read_field_string(lua_State *L, const char * field, const char *v, int tidx = INDEX_ARGS) {
    if (lua_getfield(L, tidx, field) == LUA_TSTRING) {
        v = lua_tostring(L, -1);
    }
    lua_pop(L, 1);
    return v;
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
        sz = 64;    // default buf size 64
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

extern "C"
int luaopen_imgui_legacy(lua_State *L) {
    lua_newtable(L);
    luaL_Reg l[] = {
        { "InputText", wInputText },
        { "InputTextMultiline", wInputTextMultiline },
        { "DockBuilderGetCentralRect", dDockBuilderGetCentralRect },
        { NULL, NULL },
    };
    luaL_setfuncs(L, l, 0);

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

    return 1;
}
