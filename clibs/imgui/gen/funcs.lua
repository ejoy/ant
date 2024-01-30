local AntDir, meta = ...

local w <close> = assert(io.open(AntDir.."/clibs/imgui/imgui_lua_funcs.cpp", "wb"))

local function writeln(fmt, ...)
    w:write(string.format(fmt, ...))
    w:write "\n"
end

local write_arg = {}
local write_arg_ret = {}

write_arg["const char*"] = function(type_meta, status)
    assert(not type_meta.default_value)
    status.idx = status.idx + 1
    writeln("    auto %s = luaL_checkstring(L, %d);", type_meta.name, status.idx)
    status.arguments[#status.arguments+1] = type_meta.name
end

write_arg["const void*"] = function(type_meta, status)
    local size_meta = status.args[status.i + 1]
    assert(not type_meta.default_value)
    assert(not size_meta.default_value)
    assert(size_meta.type.declaration == "size_t")
    status.idx = status.idx + 1
    status.i = status.i + 1
    writeln("    size_t %s = 0;", size_meta.name)
    writeln("    auto %s = luaL_checklstring(L, %d, &%s);", type_meta.name, status.idx, size_meta.name)
    status.arguments[#status.arguments+1] = type_meta.name
    status.arguments[#status.arguments+1] = size_meta.name
end

write_arg["ImVec2"] = function(type_meta, status)
    if type_meta.default_value == nil then
        writeln("    auto %s = ImVec2 { (float)luaL_checknumber(L, %d), (float)luaL_checknumber(L, %d) };", type_meta.name, status.idx + 1, status.idx + 2)
    else
        assert(type_meta.default_value == "ImVec2(0.0f, 0.0f)" or type_meta.default_value == "ImVec2(0, 0)", type_meta.default_value)
        writeln("    auto %s = ImVec2 { (float)luaL_optnumber(L, %d, 0.f), (float)luaL_optnumber(L, %d, 0.f) };", type_meta.name, status.idx + 1, status.idx + 2)
    end
    status.arguments[#status.arguments+1] = type_meta.name
    status.idx = status.idx + 2
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
    status.idx = status.idx + 1
    writeln("    auto has_%s = !lua_isnil(L, %d);", type_meta.name, status.idx)
    writeln("    bool %s = true;", type_meta.name)
    status.arguments[#status.arguments+1] = string.format("(has_%s? &%s: NULL)", type_meta.name, type_meta.name)
end

write_arg_ret["bool*"] = function(type_meta)
    writeln("    lua_pushboolean(L, has_%s || %s);", type_meta.name, type_meta.name)
    return 1
end

local write_ret = {}

write_ret["bool"] = function()
    writeln "    lua_pushboolean(L, _retval);"
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

write_ret["const char*"] = function()
    writeln "    lua_pushstring(L, _retval);"
    return 1
end

for _, type_name in ipairs {"int", "ImU32", "ImGuiID"} do
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

for _, enums in ipairs(meta.enums) do
    if enums.conditionals then
        goto continue
    end
    local realname = enums.name:match "(.-)_?$"
    local function find_name(value)
        local v = math.tointeger(value)
        for _, element in ipairs(enums.elements) do
            if element.value == v then
                return element.name
            end
        end
        assert(false)
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

local function write_func(func_meta)
    local realname = func_meta.name:match "^ImGui_([%w]+)$"
    writeln("static int %s(lua_State* L) {", realname)
    local status = {
        i = 1,
        args = func_meta.arguments,
        idx = 0,
        arguments = {},
    }
    while status.i <= #status.args do
        local type_meta = status.args[status.i]
        local wfunc = write_arg[type_meta.type.declaration]
        if not wfunc then
            error(string.format("undefined write arg func `%s`", type_meta.type.declaration))
        end
        wfunc(type_meta, status)
        status.i = status.i + 1
    end
    if func_meta.return_type.declaration == "void" then
        writeln("    %s(%s);", func_meta.original_fully_qualified_name, table.concat(status.arguments, ", "))
        writeln "    return 0;"
    else
        local rfunc = write_ret[func_meta.return_type.declaration]
        if not rfunc then
            error(string.format("undefined write ret func `%s`", func_meta.return_type.declaration))
        end
        writeln("    auto _retval = %s(%s);", func_meta.original_fully_qualified_name, table.concat(status.arguments, ", "))
        local nret = 0
        nret = nret + rfunc(func_meta.return_type)
        for _, type_meta in ipairs(func_meta.arguments) do
            local func = write_arg_ret[type_meta.type.declaration]
            if func then
                nret = nret + func(type_meta)
            end
        end
        writeln("    return %d;", nret)
    end
    writeln "}"
    writeln ""
    return realname
end

local allow = require "allow"

local function write_func_scope()
    local funcs = {}
    allow.init()
    for _, func_meta in ipairs(meta.functions) do
        local status = allow.query(func_meta)
        if status == "skip" then
            break
        end
        if status then
            funcs[#funcs+1] = write_func(func_meta)
        end
    end
    return funcs
end

writeln "//"
writeln "// Automatically generated file; DO NOT EDIT."
writeln "//"
writeln "#include <imgui.h>"
writeln "#include <lua.hpp>"
writeln ""
writeln "namespace imgui_lua {"
writeln ""
local funcs = write_func_scope()
writeln "void init(lua_State* L) {"
writeln "    luaL_Reg funcs[] = {"
for _, func in ipairs(funcs) do
    writeln("        { %q, %s },", func, func)
end
writeln "        { NULL, NULL },"
writeln "    };"
writeln "    luaL_setfuncs(L, funcs, 0);"
writeln "}"
writeln "}"
