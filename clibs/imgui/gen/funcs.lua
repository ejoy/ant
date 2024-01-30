local AntDir, meta = ...


local w <close> = assert(io.open(AntDir.."/clibs/imgui/imgui_lua_funcs.cpp", "wb"))

local function writeln(fmt, ...)
    w:write(string.format(fmt, ...))
    w:write "\n"
end

local write_arg = {}

write_arg["const char*"] = function(type_meta, arguments, idx)
    assert(not type_meta.default_value)
    idx = idx + 1
    writeln("    auto %s = luaL_checkstring(L, %d);", type_meta.name, idx)
    arguments[#arguments+1] = type_meta.name
    return idx
end

for _, type_name in ipairs {"int", "ImU32", "ImGuiID"} do
    write_arg[type_name] = function(type_meta, arguments, idx)
        idx = idx + 1
        if type_meta.default_value then
            writeln("    auto %s = (%s)luaL_optinteger(L, %d, %s);", type_meta.name, type_name, idx, type_meta.default_value)
        else
            writeln("    auto %s = (%s)luaL_checkinteger(L, %d);", type_meta.name, type_name, idx)
        end
        arguments[#arguments+1] = type_meta.name
        return idx
    end
end

write_arg["ImVec2"] = function(type_meta, arguments, idx)
    assert(type_meta.default_value == "ImVec2(0.0f, 0.0f)")
    idx = idx + 1
    writeln("    auto %s = ImVec2 { (float)luaL_optnumber(L, %d, 0.f), (float)luaL_optnumber(L, %d, 0.f) };", type_meta.name, idx, idx + 1)
    arguments[#arguments+1] = type_meta.name
    return idx + 1
end

write_arg["float"] = function(type_meta, arguments, idx)
    idx = idx + 1
    if type_meta.default_value then
        writeln("    auto %s = (float)luaL_optnumber(L, %d, %s);", type_meta.name, idx, type_meta.default_value)
    else
        writeln("    auto %s = (float)luaL_checknumber(L, %d);", type_meta.name, idx)
    end
    arguments[#arguments+1] = type_meta.name
    return idx
end

write_arg["bool"] = function(type_meta, arguments, idx)
    assert(not type_meta.default_value)
    idx = idx + 1
    writeln("    auto %s = !!lua_toboolean(L, %d);", type_meta.name, idx)
    arguments[#arguments+1] = type_meta.name
    return idx
end

local write_ret = {}

write_ret["bool"] = function()
    writeln "    lua_pushboolean(L, _retval);"
    writeln "    return 1;"
end

write_ret["ImGuiTableSortSpecs*"] = function()
    writeln "    //TODO"
    writeln "    lua_pushlightuserdata(L, _retval);"
    writeln "    return 1;"
end

write_ret["int"] = function()
    writeln "    lua_pushinteger(L, _retval);"
    writeln "    return 1;"
end

write_ret["const char*"] = function()
    writeln "    lua_pushstring(L, _retval);"
    writeln "    return 1;"
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
    write_arg[realname] = function(type_meta, arguments, idx)
        idx = idx + 1
        if type_meta.default_value then
            writeln("    auto %s = (%s)luaL_optinteger(L, %d, lua_Integer(%s));", type_meta.name, realname, idx, find_name(type_meta.default_value))
        else
            writeln("    auto %s = (%s)luaL_checkinteger(L, %d);", type_meta.name, realname, idx)
        end
        arguments[#arguments+1] = type_meta.name
        return idx
    end
    write_ret[realname] = function()
        writeln "    lua_pushinteger(L, _retval);"
        writeln "    return 1;"
    end
    ::continue::
end

local function write_func(func_meta)
    local realname = func_meta.name:match "^ImGui_([%w]+)$"
    writeln("static int %s(lua_State* L) {", realname)
    local idx = 0
    local arguments = {}
    for _, type_meta in ipairs(func_meta.arguments) do
        local wfunc = write_arg[type_meta.type.declaration]
        if not wfunc then
            error(string.format("undefined write arg func `%s`", type_meta.type.declaration))
        end
        idx = wfunc(type_meta, arguments, idx)
    end
    if func_meta.return_type.declaration == "void" then
        writeln("    %s(%s);", func_meta.original_fully_qualified_name, table.concat(arguments, ", "))
        writeln "    return 0;"
    else
        local rfunc = write_ret[func_meta.return_type.declaration]
        if not rfunc then
            error(string.format("undefined write ret func `%s`", func_meta.return_type.declaration))
        end
        writeln("    auto _retval = %s(%s);", func_meta.original_fully_qualified_name, table.concat(arguments, ", "))
        rfunc(func_meta.return_type)
    end
    writeln "}"
    writeln ""
    return realname
end

local function write_func_scope(s, e)
    local funcs = {}
    local within_scope = false
    for _, func_meta in ipairs(meta.functions) do
        if within_scope then
            if not func_meta.is_internal then
                funcs[#funcs+1] = write_func(func_meta)
            end
            if func_meta.name == e then
                break
            end
        else
            if func_meta.name == s then
                within_scope = true
                if not func_meta.is_internal then
                    funcs[#funcs+1] = write_func(func_meta)
                end
            end
        end
    end
    return funcs
end

writeln "#include <imgui.h>"
writeln "#include <lua.hpp>"
writeln ""
writeln "namespace imgui_lua {"
writeln ""
local funcs = write_func_scope("ImGui_BeginTable", "ImGui_TableSetBgColor")
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
