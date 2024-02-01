local builtin_type <const> = {
    ["bool"] = "boolean",
    ["int"] = "integer",
    ["unsigned int"] = "integer",
    ["ImWchar16"] = "integer",
    ["signed char"] = "integer",
    ["float"] = "number",
    ["void*"] = "lightuserdata",
    ["ImDrawData*"] = "lightuserdata",
    ["const char*"] = "string",
}

local builtin_get <const> = {
    ["boolean"] = {
        "{RET}!!lua_toboolean(L, {IDX});"
    },
    ["integer"] = {
        "{RET}luaL_checkinteger(L, {IDX});",
    },
    ["number"] = {
        "{RET}luaL_checknumber(L, {IDX});",
    },
    ["lightuserdata"] = {
        "luaL_checktype(L, {IDX}, LUA_TLIGHTUSERDATA);",
        "{RET}lua_touserdata(L, {IDX});",
    },
    ["string"] = {
        "{RET}luaL_checkstring(L, {IDX});",
    },
}

local types = {}
local enums = {}
local docs_mark = {}
local docs_queue = {}

local function init(meta)
    for _, typedef_meta in ipairs(meta.typedefs) do
        types[typedef_meta.name] = typedef_meta
    end
    for _, struct_meta in ipairs(meta.structs) do
        types[struct_meta.name] = struct_meta
    end
    for _, enum_meta in ipairs(meta.enums) do
        if enum_meta.conditionals then
            goto continue
        end
        local realname = enum_meta.name:match "(.-)_?$"
        if enum_meta.is_flags_enum then
            local name = realname:match "^ImGui(%a+)$" or realname:match "^Im(%a+)$"
            enums[realname] = string.format("ImGui.%s", name)
        end
        ::continue::
    end
end

local decode_docs_queue

local function decode_docs(name, writeln)
    if docs_mark[name] then
        return
    end
    docs_mark[name] = true
    local meta = types[name]
    if not meta then
        assert(false)
        return
    end
    if meta.kind == "struct" then
        writeln("---@class %s", name)
        for _, field in ipairs(meta.fields) do
            local builtin = builtin_type[field.type.declaration]
            if builtin then
                writeln("---@field %s %s", field.name, builtin)
            elseif enums[field.type.declaration] then
                writeln("---@field %s %s", field.name, enums[field.type.declaration])
            else
                writeln("---@field %s %s", field.name, field.type.declaration)
                docs_queue[#docs_queue+1] = field.type.declaration
            end
        end
        writeln ""
        decode_docs_queue(writeln)
    else
        local builtin = builtin_type[meta.type.declaration]
        assert(builtin)
        writeln("---@alias %s %s", name, builtin)
        writeln ""
    end
end

function decode_docs_queue(writeln)
    while true do
        local name = table.remove(docs_queue, 1)
        if not name then
            break
        end
        decode_docs(name, writeln)
    end
end

local function decode_func_builtin(name, writeln, readonly, attris, builtin, field)
    writeln("struct %s {", field.name)
    writeln "    static int getter(lua_State* L) {"
    writeln("        auto& OBJ = **(%s**)lua_touserdata(L, lua_upvalueindex(1));", name)
    writeln("        lua_push%s(L, OBJ.%s);", builtin, field.name)
    writeln "        return 1;"
    writeln "    }"
    attris.getters[#attris.getters+1] = field.name
    if not readonly then
        local templates = builtin_get[builtin]
        writeln ""
        writeln "    static int setter(lua_State* L) {"
        writeln("        auto& OBJ = **(%s**)lua_touserdata(L, lua_upvalueindex(1));", name)
        for _, line in ipairs(templates) do
            writeln("        %s", line:gsub("{([A-Z]+)}", {
                IDX = "1",
                RET = ("OBJ.%s = (%s)"):format(field.name, field.type.declaration),
            }))
        end
        writeln "        return 0;"
        writeln "    }"
        attris.setters[#attris.setters+1] = field.name
    end
    writeln "};"
    writeln ""
end

local function decode_func_attris(name, writeln, readonly, meta)
    local attris = {
        setters = {},
        getters = {},
    }
    for _, field in ipairs(meta.fields) do
        if field.conditionals then
            goto continue
        end
        local builtin = builtin_type[field.type.declaration]
        if builtin then
            decode_func_builtin(name, writeln, readonly, attris, builtin, field)
            goto continue
        end
        local field_meta = types[field.type.declaration]
        if field_meta then
            if field_meta.kind == "struct" then
                if field_meta.name == "ImVec2" then
                    writeln("struct %s {", field.name)
                    writeln "    static int getter(lua_State* L) {"
                    writeln("        auto& OBJ = **(%s**)lua_touserdata(L, lua_upvalueindex(1));", name)
                    writeln "        lua_createtable(L, 0, 2);"
                    writeln("        lua_pushnumber(L, OBJ.%s.x);", field.name)
                    writeln "        lua_setfield(L, -2, \"x\");"
                    writeln("        lua_pushnumber(L, OBJ.%s.y);", field.name)
                    writeln "        lua_setfield(L, -2, \"y\");"
                    writeln "        return 1;"
                    writeln "    }"
                    writeln "};"
                    writeln ""
                    attris.getters[#attris.getters+1] = field.name
                    goto continue
                end
            else
                builtin = builtin_type[field_meta.type.declaration]
                assert(builtin, field_meta.type.declaration)
                decode_func_builtin(name, writeln, readonly, attris, builtin, field)
                goto continue
            end
        end
        ::continue::
    end
    return attris
end

local function decode_func(name, funcs_meta, writeln, write_func)
    local meta = types[name]
    assert(meta and meta.kind == "struct")
    writeln("namespace wrap_%s {", name)
    writeln ""
    writeln "static int tag = 0;"
    writeln ""
    local funcs = {}
    for _, func_meta in ipairs(funcs_meta) do
        funcs[#funcs+1] = write_func(func_meta)
    end
    local attris = decode_func_attris(name, writeln, false, meta)
    writeln "static void init(lua_State* L) {"
    writeln "    static luaL_Reg funcs[] = {"
    for _, func_name in ipairs(funcs) do
        writeln("        { %q, %s },", func_name, func_name)
    end
    writeln "        { NULL, NULL },"
    writeln "    };"
    writeln "    static luaL_Reg setter[] = {"
    for _, attri_name in ipairs(attris.setters) do
        writeln("        { %q, %s::setter },", attri_name, attri_name)
    end
    writeln "        { NULL, NULL },"
    writeln "    };"
    writeln "    static luaL_Reg getter[] = {"
    for _, attri_name in ipairs(attris.getters) do
        writeln("        { %q, %s::getter },", attri_name, attri_name)
    end
    writeln "        { NULL, NULL },"
    writeln "    };"
    writeln "    static lua_CFunction setter_func = +[](lua_State* L) {"
    writeln "        lua_pushvalue(L, 2);"
    writeln "        if (LUA_TNIL == lua_gettable(L, lua_upvalueindex(1))) {"
    writeln("            return luaL_error(L, \"%s.%%s is invalid\", lua_tostring(L, 2));", name)
    writeln "        }"
    writeln "        lua_pushvalue(L, 3);"
    writeln "        lua_call(L, 1, 0);"
    writeln "        return 0;"
    writeln "    };"
    writeln "    static lua_CFunction getter_func = +[](lua_State* L) {"
    writeln "        lua_pushvalue(L, 2);"
    writeln "        if (LUA_TNIL == lua_gettable(L, lua_upvalueindex(1))) {"
    writeln("            return luaL_error(L, \"%s.%%s is invalid\", lua_tostring(L, 2));", name)
    writeln "        }"
    writeln "        lua_call(L, 0, 1);"
    writeln "        return 1;"
    writeln "    };"
    writeln "    lua_newuserdatauv(L, sizeof(uintptr_t), 0);"
    writeln "    int ud = lua_gettop(L);"
    writeln "    lua_newtable(L);"
    writeln "    luaL_newlibtable(L, setter);"
    writeln "    lua_pushvalue(L, ud);"
    writeln "    luaL_setfuncs(L, setter, 1);"
    writeln "    lua_pushcclosure(L, setter_func, 1);"
    writeln "    lua_setfield(L, -2, \"__newindex\");"
    writeln "    luaL_newlibtable(L, funcs);"
    writeln "    lua_pushvalue(L, ud);"
    writeln "    luaL_setfuncs(L, funcs, 1);"
    writeln "    lua_newtable(L);"
    writeln "    luaL_newlibtable(L, getter);"
    writeln "    lua_pushvalue(L, ud);"
    writeln "    luaL_setfuncs(L, getter, 1);"
    writeln "    lua_pushcclosure(L, getter_func, 1);"
    writeln "    lua_setfield(L, -2, \"__index\");"
    writeln "    lua_setmetatable(L, -2);"
    writeln "    lua_setfield(L, -2, \"__index\");"
    writeln "    lua_setmetatable(L, -2);"
    writeln "    lua_rawsetp(L, LUA_REGISTRYINDEX, &tag);"
    writeln "}"
    writeln ""
    writeln("static void fetch(lua_State* L, %s& v) {", name)
    writeln "    lua_rawgetp(L, LUA_REGISTRYINDEX, &tag);"
    writeln("    auto** ptr = (%s**)lua_touserdata(L, -1);", name)
    writeln "    *ptr = &v;"
    writeln "}"
    writeln "}"
end

local function decode_func_readonly(name, writeln)
    local meta = types[name]
    assert(meta and meta.kind == "struct")
    writeln("namespace wrap_%s {", name)
    writeln "static int tag = 0;"
    writeln ""
    local attris = decode_func_attris(name, writeln, true, meta)
    writeln "static void init(lua_State* L) {"
    writeln "    static luaL_Reg getter[] = {"
    for _, attri_name in ipairs(attris.getters) do
        writeln("        { %q, %s::getter },", attri_name, attri_name)
    end
    writeln "        { NULL, NULL },"
    writeln "    };"
    writeln "    static lua_CFunction getter_func = +[](lua_State* L) {"
    writeln "        lua_pushvalue(L, 2);"
    writeln "        if (LUA_TNIL == lua_gettable(L, lua_upvalueindex(1))) {"
    writeln("            return luaL_error(L, \"%s.%%s is invalid\", lua_tostring(L, 2));", name)
    writeln "        }"
    writeln "        lua_call(L, 0, 1);"
    writeln "        return 1;"
    writeln "    };"
    writeln "    lua_newuserdatauv(L, sizeof(uintptr_t), 0);"
    writeln "    int ud = lua_gettop(L);"
    writeln "    lua_newtable(L);"
    writeln "    luaL_newlibtable(L, getter);"
    writeln "    lua_pushvalue(L, ud);"
    writeln "    luaL_setfuncs(L, getter, 1);"
    writeln "    lua_pushcclosure(L, getter_func, 1);"
    writeln "    lua_setfield(L, -2, \"__index\");"
    writeln "    lua_setmetatable(L, -2);"
    writeln "    lua_rawsetp(L, LUA_REGISTRYINDEX, &tag);"
    writeln "}"
    writeln ""
    writeln("static void fetch(lua_State* L, %s& v) {", name)
    writeln "    lua_rawgetp(L, LUA_REGISTRYINDEX, &tag);"
    writeln("    auto** ptr = (%s**)lua_touserdata(L, -1);", name)
    writeln "    *ptr = &v;"
    writeln "}"
    writeln "}"
end

return {
    init = init,
    decode_docs = decode_docs,
    decode_func = decode_func,
    decode_func_readonly = decode_func_readonly,
}
