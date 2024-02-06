local AntDir, meta = ...

local util = require "util"
local types = require "types"

local w <close> = assert(io.open(AntDir.."/clibs/imgui/imgui_lua_funcs.cpp", "wb"))

local function writeln(fmt, ...)
    w:write(string.format(fmt, ...))
    w:write "\n"
end

local struct_list <const> = {
    { "ImGuiViewport", { "const_pointer" } },
    { "ImGuiIO", { "pointer" } },
    { "ImFontConfig", { "pointer" } },
    { "ImFontAtlas", { "const_pointer" } },
    { "ImGuiInputTextCallbackData", { "pointer" } },
}

local struct_constructor <const> = {
    "ImFontConfig",
}

local write_arg = {}
local write_arg_ret = {}
local write_ret = {}

write_arg["const char*"] = function(type_meta, status)
    local size_meta = status.args[status.i + 1]
    if size_meta then
        if size_meta.type and size_meta.type.declaration == "size_t" then
            assert(not type_meta.default_value)
            status.idx = status.idx + 1
            status.i = status.i + 1
            writeln("    size_t %s = 0;", size_meta.name)
            writeln("    auto %s = luaL_checklstring(L, %d, &%s);", type_meta.name, status.idx, size_meta.name)
            status.arguments[#status.arguments+1] = type_meta.name
            status.arguments[#status.arguments+1] = size_meta.name
            return
        end
        if size_meta.is_varargs then
            status.idx = status.idx + 1
            status.i = status.i + 1
            writeln("    const char* %s = util::format(L, %d);", type_meta.name, status.idx)
            status.arguments[#status.arguments+1] = [["%s"]]
            status.arguments[#status.arguments+1] = type_meta.name
            return
        end
    end
    status.idx = status.idx + 1
    status.arguments[#status.arguments+1] = type_meta.name
    if type_meta.default_value then
        writeln("    auto %s = luaL_optstring(L, %d, %s);", type_meta.name, status.idx, type_meta.default_value)
    else
        writeln("    auto %s = luaL_checkstring(L, %d);", type_meta.name, status.idx)
    end
end

write_arg["const void*"] = function(type_meta, status)
    local size_meta = status.args[status.i + 1]
    if size_meta and size_meta.type and size_meta.type.declaration == "size_t" then
        assert(not type_meta.default_value)
        assert(not size_meta.default_value)
        status.idx = status.idx + 1
        status.i = status.i + 1
        writeln("    size_t %s = 0;", size_meta.name)
        writeln("    auto %s = luaL_checklstring(L, %d, &%s);", type_meta.name, status.idx, size_meta.name)
        status.arguments[#status.arguments+1] = type_meta.name
        status.arguments[#status.arguments+1] = size_meta.name
        return
    end
    status.idx = status.idx + 1
    writeln("    auto %s = lua_touserdata(L, %d);", type_meta.name, status.idx)
    status.arguments[#status.arguments+1] = type_meta.name
end

write_arg["void*"] = function(type_meta, status)
    assert(type_meta.default_value == nil)
    status.idx = status.idx + 1
    status.arguments[#status.arguments+1] = type_meta.name
    writeln("    auto %s = lua_touserdata(L, %d);", type_meta.name, status.idx)
end

write_arg["char*"] = function(type_meta, status)
    local size_meta = status.args[status.i + 1]
    if size_meta and size_meta.type and size_meta.type.declaration == "size_t" then
        assert(not type_meta.default_value)
        assert(not size_meta.default_value)
        status.idx = status.idx + 1
        status.i = status.i + 1
        writeln("    auto _ebuf = util::editbuf_create(L, %d);", status.idx)
        status.arguments[#status.arguments+1] = "_ebuf->buf"
        status.arguments[#status.arguments+1] = "_ebuf->size"
        return
    end
    assert(false)
end

write_arg["ImGuiInputTextCallback"] = function(type_meta, status)
    local ud_meta = status.args[status.i + 1]
    if ud_meta and ud_meta.type and ud_meta.type.declaration == "void*" then
        status.idx = status.idx + 1
        status.i = status.i + 1
        writeln("    _ebuf->callback = %d;", status.idx)
        writeln "    auto _top = lua_gettop(L);"
        status.arguments[#status.arguments+1] = "util::editbuf_callback"
        status.arguments[#status.arguments+1] = "_ebuf"
        return
    end
    assert(false)
end

write_arg_ret["ImGuiInputTextCallback"] = function()
    writeln "    if (lua_gettop(L) != _top + 1) {"
    writeln "        lua_pop(L, 1);"
    writeln "        lua_error(L);"
    writeln "    }"
    return 0
end

write_arg["ImVec2"] = function(type_meta, status)
    if type_meta.default_value == nil then
        writeln("    auto %s = ImVec2 {", type_meta.name)
        writeln("        (float)luaL_checknumber(L, %d),", status.idx + 1)
        writeln("        (float)luaL_checknumber(L, %d),", status.idx + 2)
        writeln "    };"
    else
        local def_x, def_y = type_meta.default_value:match "^ImVec2%(([^,]+), ([^,]+)%)$"
        writeln("    auto %s = ImVec2 {", type_meta.name)
        writeln("        (float)luaL_optnumber(L, %d, %s),", status.idx + 1, def_x)
        writeln("        (float)luaL_optnumber(L, %d, %s),", status.idx + 2, def_y)
        writeln "    };"
    end
    status.arguments[#status.arguments+1] = type_meta.name
    status.idx = status.idx + 2
end

write_arg["ImVec4"] = function(type_meta, status)
    if type_meta.default_value == nil then
        writeln("    auto %s = ImVec4 {", type_meta.name)
        writeln("        (float)luaL_checknumber(L, %d),", status.idx + 1)
        writeln("        (float)luaL_checknumber(L, %d),", status.idx + 2)
        writeln("        (float)luaL_checknumber(L, %d),", status.idx + 3)
        writeln("        (float)luaL_checknumber(L, %d),", status.idx + 4)
        writeln "    };"
    else
        local def_x, def_y, def_z, def_w = type_meta.default_value:match "^ImVec4%(([^,]+), ([^,]+), ([^,]+), ([^,]+)%)$"
        writeln("    auto %s = ImVec4 {", type_meta.name)
        writeln("        (float)luaL_optnumber(L, %d, %s),", status.idx + 1, def_x)
        writeln("        (float)luaL_optnumber(L, %d, %s),", status.idx + 2, def_y)
        writeln("        (float)luaL_optnumber(L, %d, %s),", status.idx + 3, def_z)
        writeln("        (float)luaL_optnumber(L, %d, %s),", status.idx + 4, def_w)
        writeln "    };"
    end
    status.arguments[#status.arguments+1] = type_meta.name
    status.idx = status.idx + 4
end

write_arg["ImTextureID"] = function(type_meta, status)
    assert(type_meta.default_value == nil)
    status.idx = status.idx + 1
    status.arguments[#status.arguments+1] = type_meta.name
    writeln("    auto %s = util::get_texture_id(L, %d);", type_meta.name, status.idx)
end

write_ret["ImGuiViewport*"] = function()
    writeln("    wrap_ImGuiViewport::const_pointer(L, *_retval);")
    return 1
end

write_arg["const ImFontConfig*"] = function(type_meta, status)
    status.idx = status.idx + 1
    status.arguments[#status.arguments+1] = type_meta.name
    if type_meta.default_value == nil then
        writeln("    auto %s = *(const ImFontConfig**)lua_touserdata(L, %d);", type_meta.name, status.idx)
    elseif type_meta.default_value == "NULL" then
        writeln("    auto %s = lua_isnoneornil(L, %d)? NULL: *(const ImFontConfig**)lua_touserdata(L, %d);", type_meta.name, status.idx, status.idx)
    else
        assert(false)
    end
end

write_arg["ImFont*"] = function(type_meta, status)
    assert(type_meta.default_value == nil)
    status.idx = status.idx + 1
    status.arguments[#status.arguments+1] = type_meta.name
    writeln("    auto %s = (ImFont*)lua_touserdata(L, %d);", type_meta.name, status.idx)
end

write_ret["ImFont*"] = function()
    --TODO
    writeln("    lua_pushlightuserdata(L, (void*)_retval);")
    return 1
end

write_arg["const ImWchar*"] = function(type_meta, status)
    status.idx = status.idx + 1
    status.arguments[#status.arguments+1] = type_meta.name
    if type_meta.default_value == "NULL" then
        writeln("    const ImWchar* %s = NULL;", type_meta.name)
        writeln("    switch(lua_type(L, %d)) {", status.idx)
        writeln("    case LUA_TSTRING: %s = (const ImWchar*)lua_tostring(L, %d); break;", type_meta.name, status.idx)
        writeln("    case LUA_TLIGHTUSERDATA: %s = (const ImWchar*)lua_touserdata(L, %d); break;", type_meta.name, status.idx)
        writeln "    default: break;"
        writeln "    };"
    else
        assert(false)
    end
end

write_ret["const ImWchar*"] = function()
    writeln("    lua_pushlightuserdata(L, (void*)_retval);")
    return 1
end

write_arg["const ImGuiWindowClass*"] = function()
    --NOTICE: Ignore ImGuiWindowClass for now.
end

write_arg["ImGuiContext*"] = function()
    --NOTICE: Ignore ImGuiContext for now.
end

write_ret["ImGuiContext*"] = function()
    --NOTICE: Ignore ImGuiContext for now.
    writeln("   (void)_retval;")
    return 0
end

write_arg["ImFontAtlas*"] = function()
    --NOTICE: Ignore ImFontAtlas for now.
end

write_arg["float"] = function(type_meta, status)
    status.idx = status.idx + 1
    if type_meta.default_value then
        writeln("    auto %s = (float)luaL_optnumber(L, %d, %s);", type_meta.name, status.idx, type_meta.default_value)
    else
        writeln("    auto %s = (float)luaL_checknumber(L, %d);", type_meta.name, status.idx)
    end
    status.arguments[#status.arguments+1] = type_meta.name
end

write_arg["double"] = function(type_meta, status)
    status.idx = status.idx + 1
    if type_meta.default_value then
        writeln("    auto %s = (double)luaL_optnumber(L, %d, %s);", type_meta.name, status.idx, type_meta.default_value)
    else
        writeln("    auto %s = (double)luaL_checknumber(L, %d);", type_meta.name, status.idx)
    end
    status.arguments[#status.arguments+1] = type_meta.name
end

write_arg["bool"] = function(type_meta, status)
    status.idx = status.idx + 1
    status.arguments[#status.arguments+1] = type_meta.name
    if type_meta.default_value then
        writeln("    auto %s = lua_isnoneornil(L, %d)? %s: !!lua_toboolean(L, %d);", type_meta.name, status.idx, type_meta.default_value, status.idx)
    else
        writeln("    auto %s = !!lua_toboolean(L, %d);", type_meta.name, status.idx)
    end
end

write_arg["bool*"] = function(type_meta, status)
    if type_meta.default_value then
        status.idx = status.idx + 1
        writeln("    bool has_%s = !lua_isnil(L, %d);", type_meta.name, status.idx)
        writeln("    bool %s = true;", type_meta.name)
        status.arguments[#status.arguments+1] = string.format("(has_%s? &%s: NULL)", type_meta.name, type_meta.name)
        return
    end
    status.idx = status.idx + 1
    writeln("    luaL_checktype(L, %d, LUA_TTABLE);", status.idx)
    writeln("    int _%s_index = %d;", type_meta.name, status.idx)
    writeln("    bool %s[] = {", type_meta.name)
    writeln("        util::field_toboolean(L, %d, %d),", status.idx, 1)
    writeln "    };"
    status.arguments[#status.arguments+1] = type_meta.name
end

write_arg_ret["bool*"] = function(type_meta)
    if type_meta.default_value then
        writeln("    lua_pushboolean(L, has_%s || %s);", type_meta.name, type_meta.name)
        return 1
    end
    writeln "    if (_retval) {"
    writeln("        lua_pushboolean(L, %s[0]);", type_meta.name)
    writeln("        lua_seti(L, _%s_index, 1);", type_meta.name)
    writeln "    };"
    return 0
end

write_arg["size_t*"] = function(type_meta, status)
    writeln("    size_t %s = 0;", type_meta.name)
    status.arguments[#status.arguments+1] = string.format("&%s", type_meta.name, type_meta.name)
end

write_arg["unsigned int*"] = function(type_meta, status)
    status.idx = status.idx + 1
    writeln("    luaL_checktype(L, %d, LUA_TTABLE);", status.idx)
    writeln("    int _%s_index = %d;", type_meta.name, status.idx)
    writeln("    unsigned int %s[] = {", type_meta.name)
    writeln("        (unsigned int)util::field_tointeger(L, %d, 1),", status.idx)
    writeln "    };"
    status.arguments[#status.arguments+1] = type_meta.name
end
write_arg_ret["unsigned int*"] = function(type_meta)
    writeln "    if (_retval) {"
    writeln("        lua_pushinteger(L, %s[0]);", type_meta.name)
    writeln("        lua_seti(L, _%s_index, 1);", type_meta.name)
    writeln "    };"
    return 0
end

write_arg["double*"] = function(type_meta, status)
    status.idx = status.idx + 1
    writeln("    luaL_checktype(L, %d, LUA_TTABLE);", status.idx)
    writeln("    int _%s_index = %d;", type_meta.name, status.idx)
    writeln("    double %s[] = {", type_meta.name)
    writeln("        (double)util::field_tonumber(L, %d, 1),", status.idx)
    writeln "    };"
    status.arguments[#status.arguments+1] = type_meta.name
end
write_arg_ret["double*"] = function(type_meta)
    writeln "    if (_retval) {"
    writeln("        lua_pushnumber(L, %s[0]);", type_meta.name)
    writeln("        lua_seti(L, _%s_index, 1);", type_meta.name)
    writeln "    };"
    return 0
end

for n = 1, 4 do
    write_arg["int["..n.."]"] = function(type_meta, status)
        status.idx = status.idx + 1
        writeln("    luaL_checktype(L, %d, LUA_TTABLE);", status.idx)
        writeln("    int _%s_index = %d;", type_meta.name, status.idx)
        writeln("    int %s[] = {", type_meta.name)
        for i = 1, n do
            writeln("        (int)util::field_tointeger(L, %d, %d),", status.idx, i)
        end
        writeln "    };"
        status.arguments[#status.arguments+1] = type_meta.name
    end
    write_arg_ret["int["..n.."]"] = function(type_meta)
        writeln "    if (_retval) {"
        for i = 1, n do
            writeln("        lua_pushinteger(L, %s[%d]);", type_meta.name, i-1)
            writeln("        lua_seti(L, _%s_index, %d);", type_meta.name, i)
        end
        writeln "    };"
        return 0
    end
end
write_arg["int*"] = write_arg["int[1]"]
write_arg_ret["int*"] = write_arg_ret["int[1]"]

for n = 1, 4 do
    write_arg["float["..n.."]"] = function(type_meta, status)
        status.idx = status.idx + 1
        writeln("    luaL_checktype(L, %d, LUA_TTABLE);", status.idx)
        writeln("    int _%s_index = %d;", type_meta.name, status.idx)
        writeln("    float %s[] = {", type_meta.name)
        for i = 1, n do
            writeln("        (float)util::field_tonumber(L, %d, %d),", status.idx, i)
        end
        writeln "    };"
        status.arguments[#status.arguments+1] = type_meta.name
    end
    write_arg_ret["float["..n.."]"] = function(type_meta)
        writeln "    if (_retval) {"
        for i = 1, n do
            writeln("        lua_pushnumber(L, %s[%d]);", type_meta.name, i-1)
            writeln("        lua_seti(L, _%s_index, %d);", type_meta.name, i)
        end
        writeln "    };"
        return 0
    end
end
write_arg["float*"] = write_arg["float[1]"]
write_arg_ret["float*"] = write_arg_ret["float[1]"]

write_ret["bool"] = function()
    writeln "    lua_pushboolean(L, _retval);"
    return 1
end

write_ret["float"] = function()
    writeln "    lua_pushnumber(L, _retval);"
    return 1
end

write_ret["double"] = function()
    writeln "    lua_pushnumber(L, _retval);"
    return 1
end

write_ret["const ImGuiPayload*"] = function()
    writeln "    if (_retval != NULL) {"
    writeln "        lua_pushlstring(L, (const char*)_retval->Data, _retval->DataSize);"
    writeln "    } else {"
    writeln "        lua_pushnil(L);"
    writeln "    }"
    return 1
end

write_ret["const char*"] = function(func_meta)
    local type_meta = func_meta.arguments[1]
    if type_meta and type_meta.type and type_meta.type.declaration == "size_t*" then
        writeln("    lua_pushlstring(L, _retval, %s);", type_meta.name)
        return 1
    end
    writeln "    lua_pushstring(L, _retval);"
    return 1
end

write_ret["ImVec2"] = function()
    writeln "    lua_pushnumber(L, _retval.x);"
    writeln "    lua_pushnumber(L, _retval.y);"
    return 2
end

write_ret["ImVec4"] = function()
    writeln "    lua_pushnumber(L, _retval.x);"
    writeln "    lua_pushnumber(L, _retval.y);"
    writeln "    lua_pushnumber(L, _retval.z);"
    writeln "    lua_pushnumber(L, _retval.w);"
    return 4
end

write_ret["const ImVec4*"] = function()
    --NOTICE: It's actually `const ImVec4&`
    writeln "    lua_pushnumber(L, _retval.x);"
    writeln "    lua_pushnumber(L, _retval.y);"
    writeln "    lua_pushnumber(L, _retval.z);"
    writeln "    lua_pushnumber(L, _retval.w);"
    return 4
end

write_ret["ImGuiIO*"] = function()
    --NOTICE: It's actually `ImGuiIO&`
    writeln("    wrap_ImGuiIO::pointer(L, _retval);")
    return 1
end

for _, type_name in ipairs {"int", "unsigned int", "size_t", "ImU32", "ImWchar", "ImWchar16", "ImGuiID", "ImGuiKeyChord"} do
    write_arg[type_name] = function(type_meta, status)
        status.idx = status.idx + 1
        if type_meta.default_value then
            writeln("    auto %s = (%s)luaL_optinteger(L, %d, %s);", type_meta.name, type_name, status.idx, type_meta.default_value)
        else
            writeln("    auto %s = (%s)luaL_checkinteger(L, %d);", type_meta.name, type_name, status.idx)
        end
        status.arguments[#status.arguments+1] = type_meta.name
    end
    write_ret[type_name] = function()
        writeln "    lua_pushinteger(L, _retval);"
        return 1
    end
end

local function write_enum(realname, elements, new_enums)
    local lines = {}
    for _, element in ipairs(elements) do
        if not element.is_internal and not element.is_count and not element.conditionals then
            local enum_type, enum_name = element.name:match "^(%w+)_(%w+)$"
            if new_enums and enum_type ~= realname then
                local t = new_enums[enum_type]
                if t then
                    t[#t+1] = element
                else
                    new_enums[enum_type] = { element }
                end
                goto continue
            end
            lines[#lines+1] = { enum_type, enum_name }
            ::continue::
        end
    end
    local name = realname:match "^ImGui(%a+)$" or realname:match "^Im(%a+)$"
    writeln("static util::TableInteger %s[] = {", name)
    for _, line in ipairs(lines) do
        local enum_type, enum_name = line[1], line[2]
        writeln("    ENUM(%s, %s),", enum_type, enum_name)
    end
    writeln "};"
    writeln ""
    return name
end

local function write_flags_and_enums()
    writeln("#define ENUM(prefix, name) { #name, prefix##_##name }")
    writeln ""
    local flags = {}
    local enums = {}
    local new_enums = {}
    for _, enum_meta in ipairs(meta.enums) do
        if not util.conditionals(enum_meta) then
            goto continue
        end
        local realname = enum_meta.name:match "(.-)_?$"
        local function find_name(value)
            local v = math.tointeger(value)
            for _, element in ipairs(enum_meta.elements) do
                if element.value == v then
                    return element.name
                end
            end
            assert(false)
        end
        if enum_meta.is_flags_enum then
            flags[#flags+1] = write_enum(realname, enum_meta.elements)
        else
            enums[#enums+1] = write_enum(realname, enum_meta.elements, new_enums)
        end
        write_arg[realname] = function(type_meta, status)
            status.idx = status.idx + 1
            if type_meta.default_value then
                writeln("    auto %s = (%s)luaL_optinteger(L, %d, lua_Integer(%s));", type_meta.name, realname, status.idx, find_name(type_meta.default_value))
            else
                writeln("    auto %s = (%s)luaL_checkinteger(L, %d);", type_meta.name, realname, status.idx)
            end
            status.arguments[#status.arguments+1] = type_meta.name
        end
        write_ret[realname] = function()
            writeln "    lua_pushinteger(L, _retval);"
            return 1
        end
        ::continue::
    end
    for enum_type, elements in pairs(new_enums) do
        enums[#enums+1] = write_enum(enum_type, elements)
    end
    writeln("#undef ENUM")
    writeln ""
    return flags, enums
end

local function write_func(func_meta)
    local realname
    local function_string
    local status = {
        i = 1,
        args = func_meta.arguments,
        idx = 0,
        arguments = {},
    }
    if func_meta.original_class then
        realname = func_meta.name:match("^"..func_meta.original_class.."_([%w]+)$")
        status.i = 2
        writeln("static int %s(lua_State* L) {", realname)
        writeln("    auto& OBJ = **(%s**)lua_touserdata(L, lua_upvalueindex(1));", func_meta.original_class)
        function_string = ("OBJ.%s"):format(func_meta.original_fully_qualified_name);
    else
        realname = func_meta.name:match "^ImGui_([%w]+)$"
        writeln("static int %s(lua_State* L) {", realname)
        function_string = func_meta.original_fully_qualified_name
    end
    while status.i <= #status.args do
        local type_meta = status.args[status.i]
        local wfunc = write_arg[type_meta.type.declaration]
        if not wfunc then
            error(string.format("`%s` undefined write arg func `%s`", func_meta.name, type_meta.type.declaration))
        end
        wfunc(type_meta, status)
        status.i = status.i + 1
    end
    if func_meta.return_type.declaration == "void" then
        writeln("    %s(%s);", function_string, table.concat(status.arguments, ", "))
        writeln "    return 0;"
    else
        local rfunc = write_ret[func_meta.return_type.declaration]
        if not rfunc then
            error(string.format("`%s` undefined write ret func `%s`", func_meta.name, func_meta.return_type.declaration))
        end
        writeln("    auto&& _retval = %s(%s);", function_string, table.concat(status.arguments, ", "))
        local nret = 0
        nret = nret + rfunc(func_meta, func_meta.return_type)
        for _, type_meta in ipairs(func_meta.arguments) do
            if type_meta.type then
                local func = write_arg_ret[type_meta.type.declaration]
                if func then
                    nret = nret + func(type_meta)
                end
            end
        end
        writeln("    return %d;", nret)
    end
    writeln "}"
    writeln ""
    return realname
end

local function write_funcs()
    local funcs = {}
    local struct_funcs = {}
    for _, name in ipairs(struct_constructor) do
        local realname = name:match "^ImGui([%w]+)$" or name:match "^Im([%w]+)$"
        writeln("static int %s(lua_State* L) {", realname)
        --TODO: use bee::lua::newudata
        writeln("    auto _retval = (%s*)lua_newuserdatauv(L, sizeof(%s), 0);", name, name)
        writeln("    new (_retval) %s;", name)
        writeln("    wrap_%s::pointer(L, *_retval);", name)
        writeln "    return 2;"
        writeln "}"
        writeln ""
        funcs[#funcs+1] = realname
    end
    for _, func_meta in ipairs(meta.functions) do
        if util.allow(func_meta) then
            if func_meta.original_class then
                local v = struct_funcs[func_meta.original_class]
                if v then
                    v[#v+1] = func_meta
                else
                    struct_funcs[func_meta.original_class] = { func_meta }
                end
            else
                funcs[#funcs+1] = write_func(func_meta)
            end
        end
    end
    return funcs, struct_funcs
end


local function write_struct_defines()
    for _, v in ipairs(struct_list) do
        local name, modes = v[1], v[2]
        writeln("namespace wrap_%s {", name)
        for _, mode in ipairs(modes) do
            writeln("    void %s(lua_State* L, %s& v);", mode, name)
        end
        writeln "}"
    end
end

local function write_structs(struct_funcs)
    for _, v in ipairs(struct_list) do
        local name, modes = v[1], v[2]
        types.decode_func(name, struct_funcs[name] or {}, writeln, write_func, modes)
    end
end

writeln "//"
writeln "// Automatically generated file; DO NOT EDIT."
writeln "//"
writeln "#include <imgui.h>"
writeln "#include <lua.hpp>"
writeln "#include \"imgui_lua_util.h\""
writeln ""
writeln "namespace imgui_lua {"
writeln ""
local flags, enums = write_flags_and_enums()
write_struct_defines()
writeln ""
local funcs, struct_funcs = write_funcs()
write_structs(struct_funcs)
writeln "static void init(lua_State* L) {"
writeln "    static luaL_Reg funcs[] = {"
for _, func in ipairs(funcs) do
    writeln("        { %q, %s },", func, func)
end
writeln "        { NULL, NULL },"
writeln "    };"
writeln ""
writeln "    #define GEN_FLAGS(name) { #name, +[](lua_State* L){ \\"
writeln "         util::create_table(L, name); \\"
writeln "         util::flags_gen(L, #name); \\"
writeln "    }}"
writeln ""
writeln "    static util::TableAny flags[] = {"
for _, name in ipairs(flags) do
    writeln("        GEN_FLAGS(%s),", name)
end
writeln "    };"
writeln "    #undef GEN_FLAGS"
writeln ""
writeln "    #define GEN_ENUM(name) { #name, +[](lua_State* L){ \\"
writeln "         util::create_table(L, name); \\"
writeln "    }}"
writeln ""
writeln "    static util::TableAny enums[] = {"
for _, name in ipairs(enums) do
    writeln("        GEN_ENUM(%s),", name)
end
writeln "    };"
writeln "    #undef GEN_ENUM"
writeln ""
writeln "    util::init(L);"
writeln "    lua_createtable(L, 0,"
writeln "        sizeof(funcs) / sizeof(funcs[0]) - 1 +"
writeln "        sizeof(flags) / sizeof(flags[0]) +"
writeln "        sizeof(enums) / sizeof(enums[0])"
writeln "    );"
writeln "    luaL_setfuncs(L, funcs, 0);"
writeln "    util::set_table(L, flags);"
writeln "    util::set_table(L, enums);"
for _, v in ipairs(struct_list) do
    local name = v[1]
    writeln("    wrap_%s::init(L);", name)
end
writeln "}"
writeln "}"
writeln ""
writeln "extern \"C\""
writeln "int luaopen_imgui(lua_State *L) {"
writeln "    imgui_lua::init(L);"
writeln "    return 1;"
writeln "}"
