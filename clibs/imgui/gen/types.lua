local builtin_type <const> = {
    ["bool"] = "boolean",
    ["int"] = "integer",
    ["unsigned int"] = "integer",
    ["float"] = "number",
    ["void*"] = "lightuserdata",
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
}

local reserve_type <const> = {
    ["ImTextureID"] = "ImTextureID",
    ["ImGuiKeyChord"] = "ImGuiKeyChord",
    ["const ImWchar*"] = "ImFontRange",
    ["ImVec2"] = "ImVec2",
}

local special = {}

special["ImVec2"] = function (name, field, attris, writeln)
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
end

special["const ImWchar*"] = function (name, field, attris, writeln, readonly)
    writeln("struct %s {", field.name)
    writeln "    static int getter(lua_State* L) {"
    writeln("        auto& OBJ = **(%s**)lua_touserdata(L, lua_upvalueindex(1));", name)
    writeln("        lua_pushlightuserdata(L, (void*)OBJ.%s);", field.name)
    writeln "        return 1;"
    writeln "    }"
    attris.getters[#attris.getters+1] = field.name
    if not readonly then
        writeln ""
        writeln "    static int setter(lua_State* L) {"
        writeln("        auto& OBJ = **(%s**)lua_touserdata(L, lua_upvalueindex(1));", name)
        writeln("        OBJ.%s = (const ImWchar*)lua_touserdata(L, 1);", field.name, field.type.declaration)
        writeln "        return 0;"
        writeln "    }"
        attris.setters[#attris.setters+1] = field.name
    end
    writeln "};"
    writeln ""
end

special["ImGuiKeyChord"] = function (name, field, attris, writeln, readonly)
    writeln("struct %s {", field.name)
    writeln "    static int getter(lua_State* L) {"
    writeln("        auto& OBJ = **(%s**)lua_touserdata(L, lua_upvalueindex(1));", name)
    writeln("        lua_pushinteger(L, OBJ.%s);", field.name)
    writeln "        return 1;"
    writeln "    }"
    attris.getters[#attris.getters+1] = field.name
    if not readonly then
        writeln ""
        writeln "    static int setter(lua_State* L) {"
        writeln("        auto& OBJ = **(%s**)lua_touserdata(L, lua_upvalueindex(1));", name)
        writeln("        OBJ.%s = (ImGuiKeyChord)luaL_checkinteger(L, 1);", field.name, field.type.declaration)
        writeln "        return 0;"
        writeln "    }"
        attris.setters[#attris.setters+1] = field.name
    end
    writeln "};"
    writeln ""
end

special["ImTextureID"] = function ()
end

local function decode_docs(status, name, writeln, write_func)
    local lines = {}
    local maxn = 0
    local function push_line(field, typename)
        local fname = string.format("%s %s", field.name, typename)
        maxn = math.max(maxn, #fname)
        if field.comments and field.comments.attached then
            lines[#lines+1] = { fname, field.comments.attached:match "^//(.*)$" }
        else
            lines[#lines+1] = { fname }
        end
    end
    for _, field in ipairs(status.structs[name].fields) do
        if field.conditionals then
            goto continue
        end
        if field.is_internal then
            goto continue
        end
        if field.type.description.kind == "Pointer" then
            if status.structs[field.type.description.inner_type.name] then
                push_line(field, field.type.description.inner_type.name)
                goto continue
            end
        end
        if reserve_type[field.type.declaration] then
            push_line(field, reserve_type[field.type.declaration])
            goto continue
        end
        if builtin_type[field.type.declaration] then
            push_line(field, builtin_type[field.type.declaration])
            goto continue
        end
        if status.flags[field.type.declaration] then
            push_line(field, string.format("ImGui.%s", status.flags[field.type.declaration].name))
            goto continue
        end
        if status.enums[field.type.declaration] then
            push_line(field, string.format("ImGui.%s", status.enums[field.type.declaration].name))
            goto continue
        end
        if status.types[field.type.declaration] then
            push_line(field, field.type.declaration)
            goto continue
        end
        ::continue::
    end
    writeln("---@class %s", name)
    for _, line in ipairs(lines) do
        local fname, comment = line[1], line[2]
        if comment then
            writeln("---@field %s%s# %s", fname, string.rep(" ", maxn - #fname), comment)
        else
            writeln("---@field %s", fname)
        end
    end
    if not status.structs[name] or not status.structs[name].funcs then
        writeln ""
        return
    end
    writeln("local %s = {}", name)
    for _, func_meta in ipairs(status.structs[name].funcs) do
        write_func(func_meta)
    end
    writeln ""
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

local function decode_func_structs(name, writeln, readonly, attris, struct_name, field)
    writeln("struct %s {", field.name)
    writeln "    static int getter(lua_State* L) {"
    writeln("        auto& OBJ = **(%s**)lua_touserdata(L, lua_upvalueindex(1));", name)
    writeln("        wrap_%s::pointer(L, *OBJ.%s);", struct_name, field.name)
    writeln "        return 1;"
    writeln "    }"
    attris.getters[#attris.getters+1] = field.name
    writeln "};"
    writeln ""
end

local function decode_func_attris(status, name, writeln, readonly)
    local attris = {
        setters = {},
        getters = {},
    }
    for _, field in ipairs(status.structs[name].fields) do
        if field.conditionals then
            goto continue
        end
        if field.is_internal then
            goto continue
        end
        if field.type.description.kind == "Pointer" then
            if status.structs[field.type.description.inner_type.name] then
                decode_func_structs(name, writeln, readonly, attris, field.type.description.inner_type.name, field)
                goto continue
            end
        end
        if builtin_type[field.type.declaration] then
            decode_func_builtin(name, writeln, readonly, attris, builtin_type[field.type.declaration], field)
            goto continue
        end
        if status.flags[field.type.declaration] then
            decode_func_builtin(name, writeln, readonly, attris, "integer", field)
            goto continue
        end
        if status.enums[field.type.declaration] then
            decode_func_builtin(name, writeln, readonly, attris, "integer", field)
            goto continue
        end
        if status.types[field.type.declaration] then
            decode_func_builtin(name, writeln, readonly, attris, "integer", field)
            goto continue
        end
        if special[field.type.declaration] then
            special[field.type.declaration](name, field, attris, writeln, readonly)
            goto continue
        end
        ::continue::
    end
    return attris
end

local function decode_func(status, name, writeln, write_func, mode)
    writeln("namespace wrap_%s {", name)
    writeln ""
    local funcs_meta = status.structs[name].funcs or {}
    local funcs = {}
    for _, func_meta in ipairs(funcs_meta) do
        funcs[#funcs+1] = write_func(func_meta)
    end
    local readonly = mode == "const_pointer"
    local attris = decode_func_attris(status, name, writeln, readonly)
    local funcs_args = "{}"
    local setters_args = "{}"
    local getters_args = "{}"
    if #funcs > 0 then
        writeln "static luaL_Reg funcs[] = {"
        for _, func_name in ipairs(funcs) do
            writeln("    { %q, %s },", func_name, func_name)
        end
        writeln "};"
        writeln ""
        funcs_args = "funcs"
    end
    if #attris.setters > 0 then
        writeln "static luaL_Reg setters[] = {"
        for _, attri_name in ipairs(attris.setters) do
            writeln("    { %q, %s::setter },", attri_name, attri_name)
        end
        writeln "};"
        writeln ""
        setters_args = "setters"
    end
    if #attris.getters > 0 then
        writeln "static luaL_Reg getters[] = {"
        for _, attri_name in ipairs(attris.getters) do
            writeln("    { %q, %s::getter },", attri_name, attri_name)
        end
        writeln "};"
        writeln ""
        getters_args = "getters"
    end
    writeln("static int tag_%s = 0;", mode)
    writeln ""
    writeln("void %s(lua_State* L, %s& v) {", mode, name)
    writeln("    lua_rawgetp(L, LUA_REGISTRYINDEX, &tag_%s);", mode)
    writeln("    auto** ptr = (%s**)lua_touserdata(L, -1);", name)
    writeln "    *ptr = &v;"
    writeln "}"
    writeln ""
    writeln "static void init(lua_State* L) {"
    if mode == "const_pointer" then
        writeln("    util::struct_gen(L, %q, %s, {}, %s);", name, funcs_args, getters_args)
    elseif mode == "pointer" then
        writeln("    util::struct_gen(L, %q, %s, %s, %s);", name, funcs_args, setters_args, getters_args)
    else
        assert(false)
    end
    writeln("    lua_rawsetp(L, LUA_REGISTRYINDEX, &tag_%s);", mode)
    writeln "}"
    writeln ""
    writeln "}"
    writeln ""
end

return {
    decode_docs = decode_docs,
    decode_func = decode_func,
}
