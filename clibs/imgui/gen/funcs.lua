local status = ...

local types = require "types"

local function writeln(fmt, ...)
    local w = status.apis_file
    w:write(string.format(fmt, ...))
    w:write "\n"
end

local write_arg = {}
local write_arg_ret = {}
local write_ret = {}

write_arg["const char*"] = function(type_meta, context)
    local size_meta = context.args[context.i + 1]
    if size_meta then
        if size_meta.type and size_meta.type.declaration == "size_t" then
            assert(not type_meta.default_value)
            context.idx = context.idx + 1
            context.i = context.i + 1
            writeln("    size_t %s = 0;", size_meta.name)
            writeln("    auto %s = luaL_checklstring(L, %d, &%s);", type_meta.name, context.idx, size_meta.name)
            context.arguments[#context.arguments+1] = type_meta.name
            context.arguments[#context.arguments+1] = size_meta.name
            return
        end
        if size_meta.is_varargs then
            context.idx = context.idx + 1
            context.i = context.i + 1
            writeln("    const char* %s = util::format(L, %d);", type_meta.name, context.idx)
            context.arguments[#context.arguments+1] = [["%s"]]
            context.arguments[#context.arguments+1] = type_meta.name
            return
        end
    end
    context.idx = context.idx + 1
    context.arguments[#context.arguments+1] = type_meta.name
    if type_meta.default_value then
        writeln("    auto %s = luaL_optstring(L, %d, %s);", type_meta.name, context.idx, type_meta.default_value)
    else
        writeln("    auto %s = luaL_checkstring(L, %d);", type_meta.name, context.idx)
    end
end

write_arg["const void*"] = function(type_meta, context)
    local size_meta = context.args[context.i + 1]
    if size_meta and size_meta.type and size_meta.type.declaration == "size_t" then
        assert(not type_meta.default_value)
        assert(not size_meta.default_value)
        context.idx = context.idx + 1
        context.i = context.i + 1
        writeln("    size_t %s = 0;", size_meta.name)
        writeln("    auto %s = luaL_checklstring(L, %d, &%s);", type_meta.name, context.idx, size_meta.name)
        context.arguments[#context.arguments+1] = type_meta.name
        context.arguments[#context.arguments+1] = size_meta.name
        return
    end
    context.idx = context.idx + 1
    writeln("    auto %s = lua_touserdata(L, %d);", type_meta.name, context.idx)
    context.arguments[#context.arguments+1] = type_meta.name
end

write_arg["void*"] = function(type_meta, context)
    context.idx = context.idx + 1
    context.arguments[#context.arguments+1] = type_meta.name
    if type_meta.default_value == nil then
        writeln("    auto %s = lua_touserdata(L, %d);", type_meta.name, context.idx)
    elseif type_meta.default_value == "NULL" then
        writeln("    auto %s = lua_isnoneornil(L, %d)? NULL: lua_touserdata(L, %d);", type_meta.name, context.idx, context.idx)
    else
        assert(false)
    end
end

write_arg["char*"] = function(type_meta, context)
    local size_meta = context.args[context.i + 1]
    if size_meta and size_meta.type and size_meta.type.declaration == "size_t" then
        assert(not type_meta.default_value)
        assert(not size_meta.default_value)
        context.idx = context.idx + 1
        context.i = context.i + 1
        writeln("    auto _strbuf = util::strbuf_get(L, %d);", context.idx)
        context.arguments[#context.arguments+1] = "_strbuf->data"
        context.arguments[#context.arguments+1] = "_strbuf->size"
        return
    end
    assert(false)
end

write_arg["ImGuiInputTextCallback"] = function(type_meta, context)
    local ud_meta = context.args[context.i + 1]
    if ud_meta and ud_meta.type and ud_meta.type.declaration == "void*" then
        context.idx = context.idx + 1
        context.i = context.i + 1
        writeln("    util::input_context _ctx { L, %d };", context.idx)
        writeln "    auto _top = lua_gettop(L);"
        context.arguments[#context.arguments+1] = "util::input_callback"
        context.arguments[#context.arguments+1] = "&_ctx"
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

write_arg["ImVec2"] = function(type_meta, context)
    if type_meta.default_value == nil then
        writeln("    auto %s = ImVec2 {", type_meta.name)
        writeln("        (float)luaL_checknumber(L, %d),", context.idx + 1)
        writeln("        (float)luaL_checknumber(L, %d),", context.idx + 2)
        writeln "    };"
    else
        local def_x, def_y = type_meta.default_value:match "^ImVec2%(([^,]+), ([^,]+)%)$"
        writeln("    auto %s = ImVec2 {", type_meta.name)
        writeln("        (float)luaL_optnumber(L, %d, %s),", context.idx + 1, def_x)
        writeln("        (float)luaL_optnumber(L, %d, %s),", context.idx + 2, def_y)
        writeln "    };"
    end
    context.arguments[#context.arguments+1] = type_meta.name
    context.idx = context.idx + 2
end

write_arg["ImVec4"] = function(type_meta, context)
    if type_meta.default_value == nil then
        writeln("    auto %s = ImVec4 {", type_meta.name)
        writeln("        (float)luaL_checknumber(L, %d),", context.idx + 1)
        writeln("        (float)luaL_checknumber(L, %d),", context.idx + 2)
        writeln("        (float)luaL_checknumber(L, %d),", context.idx + 3)
        writeln("        (float)luaL_checknumber(L, %d),", context.idx + 4)
        writeln "    };"
    else
        local def_x, def_y, def_z, def_w = type_meta.default_value:match "^ImVec4%(([^,]+), ([^,]+), ([^,]+), ([^,]+)%)$"
        writeln("    auto %s = ImVec4 {", type_meta.name)
        writeln("        (float)luaL_optnumber(L, %d, %s),", context.idx + 1, def_x)
        writeln("        (float)luaL_optnumber(L, %d, %s),", context.idx + 2, def_y)
        writeln("        (float)luaL_optnumber(L, %d, %s),", context.idx + 3, def_z)
        writeln("        (float)luaL_optnumber(L, %d, %s),", context.idx + 4, def_w)
        writeln "    };"
    end
    context.arguments[#context.arguments+1] = type_meta.name
    context.idx = context.idx + 4
end

write_arg["ImTextureID"] = function(type_meta, context)
    assert(type_meta.default_value == nil)
    context.idx = context.idx + 1
    context.arguments[#context.arguments+1] = type_meta.name
    writeln("    auto %s = util::get_texture_id(L, %d);", type_meta.name, context.idx)
end

write_arg["ImFont*"] = function(type_meta, context)
    assert(type_meta.default_value == nil)
    context.idx = context.idx + 1
    context.arguments[#context.arguments+1] = type_meta.name
    writeln("    auto %s = (ImFont*)lua_touserdata(L, %d);", type_meta.name, context.idx)
end

write_ret["ImFont*"] = function()
    --TODO
    writeln("    lua_pushlightuserdata(L, (void*)_retval);")
    return 1
end

write_arg["const ImWchar*"] = function(type_meta, context)
    context.idx = context.idx + 1
    context.arguments[#context.arguments+1] = type_meta.name
    if type_meta.default_value == "NULL" then
        writeln("    const ImWchar* %s = NULL;", type_meta.name)
        writeln("    switch(lua_type(L, %d)) {", context.idx)
        writeln("    case LUA_TSTRING: %s = (const ImWchar*)lua_tostring(L, %d); break;", type_meta.name, context.idx)
        writeln("    case LUA_TLIGHTUSERDATA: %s = (const ImWchar*)lua_touserdata(L, %d); break;", type_meta.name, context.idx)
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

write_arg["float"] = function(type_meta, context)
    context.idx = context.idx + 1
    if type_meta.default_value then
        writeln("    auto %s = (float)luaL_optnumber(L, %d, %s);", type_meta.name, context.idx, type_meta.default_value)
    else
        writeln("    auto %s = (float)luaL_checknumber(L, %d);", type_meta.name, context.idx)
    end
    context.arguments[#context.arguments+1] = type_meta.name
end

write_arg["double"] = function(type_meta, context)
    context.idx = context.idx + 1
    if type_meta.default_value then
        writeln("    auto %s = (double)luaL_optnumber(L, %d, %s);", type_meta.name, context.idx, type_meta.default_value)
    else
        writeln("    auto %s = (double)luaL_checknumber(L, %d);", type_meta.name, context.idx)
    end
    context.arguments[#context.arguments+1] = type_meta.name
end

write_arg["bool"] = function(type_meta, context)
    context.idx = context.idx + 1
    context.arguments[#context.arguments+1] = type_meta.name
    if type_meta.default_value then
        writeln("    auto %s = lua_isnoneornil(L, %d)? %s: !!lua_toboolean(L, %d);", type_meta.name, context.idx, type_meta.default_value, context.idx)
    else
        writeln("    auto %s = !!lua_toboolean(L, %d);", type_meta.name, context.idx)
    end
end

write_arg["bool*"] = function(type_meta, context)
    if type_meta.default_value then
        context.idx = context.idx + 1
        writeln("    bool has_%s = !lua_isnil(L, %d);", type_meta.name, context.idx)
        writeln("    bool %s = true;", type_meta.name)
        context.arguments[#context.arguments+1] = string.format("(has_%s? &%s: NULL)", type_meta.name, type_meta.name)
        return
    end
    context.idx = context.idx + 1
    writeln("    luaL_checktype(L, %d, LUA_TTABLE);", context.idx)
    writeln("    int _%s_index = %d;", type_meta.name, context.idx)
    writeln("    bool %s[] = {", type_meta.name)
    writeln("        util::field_toboolean(L, %d, %d),", context.idx, 1)
    writeln "    };"
    context.arguments[#context.arguments+1] = type_meta.name
end

write_arg_ret["bool*"] = function(type_meta)
    if type_meta.default_value then
        writeln("    if (has_%s) {", type_meta.name)
        writeln("        lua_pushboolean(L, %s);", type_meta.name)
        writeln("    } else {")
        writeln("        lua_pushnil(L);")
        writeln("    }")
        return 1
    end
    writeln "    if (_retval) {"
    writeln("        lua_pushboolean(L, %s[0]);", type_meta.name)
    writeln("        lua_seti(L, _%s_index, 1);", type_meta.name)
    writeln "    };"
    return 0
end

write_arg["size_t*"] = function(type_meta, context)
    writeln("    size_t %s = 0;", type_meta.name)
    context.arguments[#context.arguments+1] = string.format("&%s", type_meta.name, type_meta.name)
end

write_arg["unsigned int*"] = function(type_meta, context)
    context.idx = context.idx + 1
    writeln("    luaL_checktype(L, %d, LUA_TTABLE);", context.idx)
    writeln("    int _%s_index = %d;", type_meta.name, context.idx)
    writeln("    unsigned int %s[] = {", type_meta.name)
    writeln("        (unsigned int)util::field_tointeger(L, %d, 1),", context.idx)
    writeln "    };"
    context.arguments[#context.arguments+1] = type_meta.name
end
write_arg_ret["unsigned int*"] = function(type_meta)
    writeln "    if (_retval) {"
    writeln("        lua_pushinteger(L, %s[0]);", type_meta.name)
    writeln("        lua_seti(L, _%s_index, 1);", type_meta.name)
    writeln "    };"
    return 0
end

write_arg["double*"] = function(type_meta, context)
    context.idx = context.idx + 1
    writeln("    luaL_checktype(L, %d, LUA_TTABLE);", context.idx)
    writeln("    int _%s_index = %d;", type_meta.name, context.idx)
    writeln("    double %s[] = {", type_meta.name)
    writeln("        (double)util::field_tonumber(L, %d, 1),", context.idx)
    writeln "    };"
    context.arguments[#context.arguments+1] = type_meta.name
end
write_arg_ret["double*"] = function(type_meta)
    writeln "    if (_retval) {"
    writeln("        lua_pushnumber(L, %s[0]);", type_meta.name)
    writeln("        lua_seti(L, _%s_index, 1);", type_meta.name)
    writeln "    };"
    return 0
end

for n = 1, 4 do
    write_arg["int["..n.."]"] = function(type_meta, context)
        context.idx = context.idx + 1
        writeln("    luaL_checktype(L, %d, LUA_TTABLE);", context.idx)
        writeln("    int _%s_index = %d;", type_meta.name, context.idx)
        writeln("    int %s[] = {", type_meta.name)
        for i = 1, n do
            writeln("        (int)util::field_tointeger(L, %d, %d),", context.idx, i)
        end
        writeln "    };"
        context.arguments[#context.arguments+1] = type_meta.name
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
    write_arg["float["..n.."]"] = function(type_meta, context)
        context.idx = context.idx + 1
        writeln("    luaL_checktype(L, %d, LUA_TTABLE);", context.idx)
        writeln("    int _%s_index = %d;", type_meta.name, context.idx)
        writeln("    float %s[] = {", type_meta.name)
        for i = 1, n do
            writeln("        (float)util::field_tonumber(L, %d, %d),", context.idx, i)
        end
        writeln "    };"
        context.arguments[#context.arguments+1] = type_meta.name
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

for _, type_name in ipairs {"int", "unsigned int", "size_t", "ImU32", "ImWchar", "ImWchar16", "ImDrawIdx", "ImGuiID", "ImGuiKeyChord"} do
    write_arg[type_name] = function(type_meta, context)
        context.idx = context.idx + 1
        if type_meta.default_value then
            writeln("    auto %s = (%s)luaL_optinteger(L, %d, %s);", type_meta.name, type_name, context.idx, type_meta.default_value)
        else
            writeln("    auto %s = (%s)luaL_checkinteger(L, %d);", type_meta.name, type_name, context.idx)
        end
        context.arguments[#context.arguments+1] = type_meta.name
    end
    write_ret[type_name] = function()
        writeln "    lua_pushinteger(L, _retval);"
        return 1
    end
end

local function write_enum(name, realname, elements)
    writeln("static util::TableInteger %s[] = {", name)
    for _, element in ipairs(elements) do
        writeln("    ENUM(%s, %s),", realname, element.name)
    end
    writeln "};"
    writeln ""
    return name
end

local function write_flags_and_enums()
    writeln("#define ENUM(prefix, name) { #name, prefix##_##name }")
    writeln ""
    local function init_enum(realname, elements)
        local function find_name(value)
            local v = math.tointeger(value)
            for _, element in ipairs(elements) do
                if element.value == v then
                    return realname.."_"..element.name
                end
            end
            assert(false)
        end
        write_arg[realname] = function(type_meta, context)
            context.idx = context.idx + 1
            if type_meta.default_value then
                writeln("    auto %s = (%s)luaL_optinteger(L, %d, lua_Integer(%s));", type_meta.name, realname, context.idx, find_name(type_meta.default_value))
            else
                writeln("    auto %s = (%s)luaL_checkinteger(L, %d);", type_meta.name, realname, context.idx)
            end
            context.arguments[#context.arguments+1] = type_meta.name
        end
        write_ret[realname] = function()
            writeln "    lua_pushinteger(L, _retval);"
            return 1
        end
    end
    for _, v in ipairs(status.flags) do
        write_enum(v.name, v.realname, v.elements)
        init_enum(v.realname, v.elements)
    end
    for _, v in ipairs(status.enums) do
        write_enum(v.name, v.realname, v.elements)
        init_enum(v.realname, v.elements)
    end
    writeln("#undef ENUM")
    writeln ""
end

local function write_func(func_meta)
    local realname
    local function_string
    local context = {
        i = 1,
        args = func_meta.arguments,
        idx = 0,
        arguments = {},
    }
    if func_meta.original_class then
        realname = func_meta.name:match("^"..func_meta.original_class.."_([%w_]+)$")
        context.i = 2
        writeln("static int %s(lua_State* L) {", realname)
        writeln("    auto& OBJ = **(%s**)lua_touserdata(L, lua_upvalueindex(1));", func_meta.original_class)
        function_string = ("OBJ.%s"):format(func_meta.original_fully_qualified_name);
    else
        realname = func_meta.name:match "^ImGui_([%w_]+)$"
        writeln("static int %s(lua_State* L) {", realname)
        function_string = func_meta.original_fully_qualified_name
    end
    while context.i <= #context.args do
        local type_meta = context.args[context.i]
        local wfunc = write_arg[type_meta.type.declaration]
        if not wfunc then
            error(string.format("`%s` undefined write arg func `%s`", func_meta.name, type_meta.type.declaration))
        end
        wfunc(type_meta, context)
        context.i = context.i + 1
    end
    if func_meta.return_type.declaration == "void" then
        writeln("    %s(%s);", function_string, table.concat(context.arguments, ", "))
        writeln "    return 0;"
    else
        local rfunc = write_ret[func_meta.return_type.declaration]
        if not rfunc then
            error(string.format("`%s` undefined write ret func `%s`", func_meta.name, func_meta.return_type.declaration))
        end
        writeln("    auto&& _retval = %s(%s);", function_string, table.concat(context.arguments, ", "))
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
    for _, v in ipairs(status.structs) do
        if v.forward_declaration then
            goto continue
        end
        local name = v.name
        local realname = name:match "^ImGui([%w]+)$" or name:match "^Im([%w]+)$"
        writeln("static int %s(lua_State* L) {", realname)
        --TODO: use bee::lua::newudata
        writeln("    auto _retval = (%s*)lua_newuserdatauv(L, sizeof(%s), 0);", name, name)
        writeln("    new (_retval) %s;", name)
        writeln("    wrap_%s::%s(L, *_retval);", name, v.mode)
        writeln "    return 2;"
        writeln "}"
        writeln ""
        funcs[#funcs+1] = realname
        ::continue::
    end
    writeln "static int StringBuf(lua_State* L) {"
    writeln "    util::strbuf_create(L, 1);"
    writeln "    return 1;"
    writeln "}"
    writeln ""
    funcs[#funcs+1] = "StringBuf"
    for _, func_meta in ipairs(status.funcs) do
        funcs[#funcs+1] = write_func(func_meta)
    end
    return funcs
end


local function write_struct_defines()
    for _, v in ipairs(status.structs) do
        local name = v.name
        for _, nametype in ipairs { "const "..name.."*", name.."*" } do
            write_arg[nametype] = function(type_meta, context)
                context.idx = context.idx + 1
                context.arguments[#context.arguments+1] = type_meta.name
                if type_meta.default_value == nil then
                    writeln("    auto %s = *(%s*)lua_touserdata(L, %d);", type_meta.name, nametype, context.idx)
                elseif type_meta.default_value == "NULL" then
                    writeln("    auto %s = lua_isnoneornil(L, %d)? NULL: *(%s*)lua_touserdata(L, %d);", type_meta.name, context.idx, nametype, context.idx)
                else
                    assert(false)
                end
            end
        end
        if v.reference then
            write_ret[name.."*"] = function()
                writeln("    wrap_%s::pointer(L, _retval);", name)
                return 1
            end
        elseif v.mode == "pointer" then
            write_ret[name.."*"] = function()
                writeln "    if (_retval != NULL) {"
                writeln("        wrap_%s::pointer(L, *_retval);", name)
                writeln "    } else {"
                writeln "        lua_pushnil(L);"
                writeln "    }"
                return 1
            end
        elseif v.mode == "const_pointer" then
            write_ret[name.."*"] = function()
                writeln("    wrap_%s::const_pointer(L, *_retval);", name)
                return 1
            end
        else
            assert(false)
        end
    end
    for _, v in ipairs(status.structs) do
        writeln("namespace wrap_%s {", v.name)
        writeln("    void %s(lua_State* L, %s& v);", v.mode, v.name)
        writeln "}"
    end
end

local function write_structs()
    for _, v in ipairs(status.structs) do
        types.decode_func(status, v.name, writeln, write_func, v.mode)
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
write_flags_and_enums()
write_struct_defines()
writeln ""
local funcs = write_funcs()
write_structs()
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
for _, v in ipairs(status.flags) do
    writeln("        GEN_FLAGS(%s),", v.name)
end
writeln "    };"
writeln "    #undef GEN_FLAGS"
writeln ""
writeln "    #define GEN_ENUM(name) { #name, +[](lua_State* L){ \\"
writeln "         util::create_table(L, name); \\"
writeln "    }}"
writeln ""
writeln "    static util::TableAny enums[] = {"
for _, v in ipairs(status.enums) do
    writeln("        GEN_ENUM(%s),", v.name)
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
for _, v in ipairs(status.structs) do
    writeln("    wrap_%s::init(L);", v.name)
end
writeln "}"
writeln "}"
writeln ""
writeln "extern \"C\""
writeln "int luaopen_imgui(lua_State *L) {"
writeln "    imgui_lua::init(L);"
writeln "    return 1;"
writeln "}"
