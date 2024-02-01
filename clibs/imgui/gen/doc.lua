local AntDir, meta = ...

local util = require "util"
local types = require "types"

local w <close> = assert(io.open(AntDir.."/misc/meta/imgui.lua", "wb"))

local function writeln(fmt, ...)
    w:write(string.format(fmt, ...))
    w:write "\n"
end

local KEYWORD <const> = {
    ["repeat"] = "arg_repeat",
    ["in"] = "arg_in",
}

local function safe_name(v)
    return KEYWORD[v] or v
end

local lua_type = {
    ["const char*"] = "string",
    ["bool"] = "boolean",
    ["float"] = "number",
    ["double"] = "number",
    ["unsigned int"] = "integer",
    ["int"] = "integer",
    ["size_t"] = "integer",
    ["ImGuiID"] = "integer",
    ["ImWchar16"] = "integer",
    ["ImU32"] = "integer",
    ["ImGuiKeyChord"] = "ImGui.KeyChord",
    ["const ImGuiPayload*"] = "string | nil",
}

local special_arg = {}
local special_ret = {}
local return_type = {}
local default_type = {}

local function get_default_value(type_meta)
    local func = default_type[type_meta.type.declaration]
    if func then
        return func(type_meta.default_value)
    end
    return type_meta.default_value
end

local function convert_float(f)
    if f == "-FLT_MIN" then
        return "-math.huge"
    end
    return f:match "^(.-)f?$"
end

special_arg["ImVec2"] = function (type_meta, status)
    if type_meta.default_value == nil then
        writeln("---@param %s_x number", type_meta.name)
        writeln("---@param %s_y number", type_meta.name)
    else
        local def_x, def_y = type_meta.default_value:match "^ImVec2%(([^,]+), ([^,]+)%)$"
        writeln("---@param %s_x? number | `%s`", type_meta.name, convert_float(def_x))
        writeln("---@param %s_y? number | `%s`", type_meta.name, convert_float(def_y))
    end
    status.arguments[#status.arguments+1] = type_meta.name .. "_x"
    status.arguments[#status.arguments+1] = type_meta.name .. "_y"
end

special_ret["ImVec2"] = function ()
    writeln("---@return number")
    writeln("---@return number")
end

special_arg["ImVec4"] = function (type_meta, status)
    if type_meta.default_value == nil then
        writeln("---@param %s_x number", type_meta.name)
        writeln("---@param %s_y number", type_meta.name)
        writeln("---@param %s_z number", type_meta.name)
        writeln("---@param %s_w number", type_meta.name)
    else
        local def_x, def_y, def_z, def_w = type_meta.default_value:match "^ImVec4%(([^,]+), ([^,]+), ([^,]+), ([^,]+)%)$"
        writeln("---@param %s_x? number | `%s`", type_meta.name, convert_float(def_x))
        writeln("---@param %s_y? number | `%s`", type_meta.name, convert_float(def_y))
        writeln("---@param %s_z? number | `%s`", type_meta.name, convert_float(def_z))
        writeln("---@param %s_w? number | `%s`", type_meta.name, convert_float(def_w))
    end
    status.arguments[#status.arguments+1] = type_meta.name .. "_x"
    status.arguments[#status.arguments+1] = type_meta.name .. "_y"
    status.arguments[#status.arguments+1] = type_meta.name .. "_z"
    status.arguments[#status.arguments+1] = type_meta.name .. "_w"
end

special_ret["ImVec4"] = function ()
    writeln("---@return number")
    writeln("---@return number")
    writeln("---@return number")
    writeln("---@return number")
end

special_ret["const ImVec4*"] = function ()
    writeln("---@return number")
    writeln("---@return number")
    writeln("---@return number")
    writeln("---@return number")
end

special_arg["ImTextureID"] = function (type_meta, status)
    assert(type_meta.default_value == nil)
    writeln("---@param %s ImTextureID", safe_name(type_meta.name))
    status.arguments[#status.arguments+1] = safe_name(type_meta.name)
end

special_ret["ImGuiViewport*"] = function()
    writeln("---@return ImGuiViewport")
end

special_arg["const ImGuiWindowClass*"] = function()
    --NOTICE: Ignore ImGuiWindowClass for now.
end

special_arg["ImGuiContext*"] = function()
    --NOTICE: Ignore ImGuiContext for now.
end

special_ret["ImGuiContext*"] = function()
    --NOTICE: Ignore ImGuiContext for now.
end

special_arg["ImFontAtlas*"] = function()
    --NOTICE: Ignore ImFontAtlas for now.
end

special_arg["unsigned int*"] = function (type_meta, status)
    assert(type_meta.default_value == nil)
    writeln("---@param %s integer[]", safe_name(type_meta.name))
    status.arguments[#status.arguments+1] = safe_name(type_meta.name)
end

special_arg["double*"] = function (type_meta, status)
    assert(type_meta.default_value == nil)
    writeln("---@param %s number[]", safe_name(type_meta.name))
    status.arguments[#status.arguments+1] = safe_name(type_meta.name)
end

--TODO: 指定数组长度
for n = 1, 4 do
    special_arg["int["..n.."]"] = function (type_meta, status)
        assert(type_meta.default_value == nil)
        writeln("---@param %s integer[]", safe_name(type_meta.name))
        status.arguments[#status.arguments+1] = safe_name(type_meta.name)
    end
end
special_arg["int*"] = special_arg["int[1]"]

for n = 1, 4 do
    special_arg["float["..n.."]"] = function (type_meta, status)
        assert(type_meta.default_value == nil)
        writeln("---@param %s number[]", safe_name(type_meta.name))
        status.arguments[#status.arguments+1] = safe_name(type_meta.name)
    end
end
special_arg["float*"] = special_arg["float[1]"]

special_arg["bool*"] = function (type_meta, status)
    if type_meta.default_value then
        writeln("---@param %s true | nil", safe_name(type_meta.name))
        status.arguments[#status.arguments+1] = safe_name(type_meta.name)
        return
    end
    writeln("---@param %s boolean[]", safe_name(type_meta.name))
    status.arguments[#status.arguments+1] = safe_name(type_meta.name)
end

special_arg["size_t*"] = function ()
end

special_arg["const char*"] = function (type_meta, status)
    local size_meta = status.args[status.i + 1]
    if size_meta then
        if size_meta.type and size_meta.type.declaration == "size_t" then
            assert(not type_meta.default_value)
            status.i = status.i + 1
            writeln("---@param %s string", safe_name(type_meta.name))
            status.arguments[#status.arguments+1] = safe_name(type_meta.name)
            return
        end
        if size_meta.is_varargs then
            status.i = status.i + 1
            writeln("---@param %s string", safe_name(type_meta.name))
            writeln "---@param ...  any"
            status.arguments[#status.arguments+1] = safe_name(type_meta.name)
            status.arguments[#status.arguments+1] = "..."
            return
        end
    end
    if type_meta.default_value then
        local default_value = get_default_value(type_meta)
        if default_value then
            writeln("---@param %s? string | `%s`", safe_name(type_meta.name), default_value)
        else
            writeln("---@param %s? string", safe_name(type_meta.name))
        end
    else
        writeln("---@param %s string", safe_name(type_meta.name))
    end
    status.arguments[#status.arguments+1] = safe_name(type_meta.name)
end

special_arg["const void*"] = function (type_meta, status)
    local size_meta = status.args[status.i + 1]
    if size_meta and size_meta.type and size_meta.type.declaration == "size_t" then
        assert(not type_meta.default_value)
        assert(not size_meta.default_value)
        status.i = status.i + 1
        writeln("---@param %s string", safe_name(type_meta.name))
        status.arguments[#status.arguments+1] = safe_name(type_meta.name)
        return
    end
    writeln("---@param %s lightuserdata", safe_name(type_meta.name))
    status.arguments[#status.arguments+1] = safe_name(type_meta.name)
end

return_type["bool*"] = function (type_meta)
    writeln("---@return boolean %s", safe_name(type_meta.name))
end

default_type["float"] = function (value)
    return value:match "^(.*)f$"
end

default_type["const char*"] = function (value)
    if value == "NULL" then
        return
    end
    return value
end

local function write_enum(realname, elements, new_enums)
    local name = string.format("ImGui.%s", realname:match "^ImGui(%a+)$")
    local function fullname(element)
        local fieldname = element.name:sub(#realname+2)
        if fieldname:match "^[0-9]" then
            return name.."["..fieldname.."]"
        else
            return name.."."..fieldname
        end
    end
    local lines = {}
    local maxn = 0
    for _, element in ipairs(elements) do
        if not element.is_internal and not element.is_count and not element.conditionals then
            if new_enums then
                local enum_type = element.name:match "^(%w+)_%w+$"
                if enum_type ~= realname then
                    local t = new_enums[enum_type]
                    if t then
                        t[#t+1] = element
                    else
                        new_enums[enum_type] = { element }
                    end
                    goto continue
                end
            end
            local fname = fullname(element)
            maxn = math.max(maxn, #fname)
            if element.comments and element.comments.attached then
                lines[#lines+1] = { fname, element.comments.attached:match "^//(.*)$" }
            else
                lines[#lines+1] = { fname }
            end
            ::continue::
        end
    end
    writeln("---@alias %s", name)
    for _, line in ipairs(lines) do
        local fname, comment = line[1], line[2]
        if comment then
            writeln("---| `%s` %s# %s", fname, string.rep(" ", maxn - #fname), comment)
        else
            writeln("---| `%s`", fname)
        end
    end
    writeln("%s = {}", name)
    lua_type[realname] = name
    default_type[realname] = function (value)
        local v = math.tointeger(value)
        for _, element in ipairs(elements) do
            if element.value == v then
                return fullname(element)
            end
        end
    end
end

local function write_flags(realname, elements)
    local name = string.format("ImGui.%s", realname:match "^ImGui(%a+)$" or realname:match "^Im(%a+)$")
    local lines = {}
    local maxn = 0
    for _, element in ipairs(elements) do
        if not element.is_internal and not element.conditionals then
            local fname = element.name:sub(#realname+2)
            maxn = math.max(maxn, #fname)
            if element.comments and element.comments.attached then
                lines[#lines+1] = { fname, element.comments.attached:match "^//(.*)$" }
            else
                lines[#lines+1] = { fname }
            end
        end
    end
    writeln("---@class %s", name)
    writeln ""
    writeln("---@alias _%s_Name", realname)
    for _, line in ipairs(lines) do
        local fname, comment = line[1], line[2]
        if comment then
            writeln("---| %q %s# %s", fname, string.rep(" ", maxn - #fname), comment)
        else
            writeln("---| %q", fname)
        end
    end
    writeln ""
    writeln("---@param flags _%s_Name[]", realname)
    writeln("---@return %s", name)
    writeln("function %s(flags) end", name)
    lua_type[realname] = name
    default_type[realname] = function (value)
        local v = math.tointeger(value)
        for _, element in ipairs(elements) do
            if element.value == v then
                return string.format("%s { %q }", name, element.name:sub(#realname+2))
            end
        end
    end
end

local function write_flags_and_enums()
    local new_enums = {}
    for _, enums in ipairs(meta.enums) do
        if not util.conditionals(enums) then
            goto continue
        end
        local realname = enums.name:match "(.-)_?$"
        if enums.comments then
            if enums.comments.preceding then
                writeln "--"
                for _, line in pairs(enums.comments.preceding) do
                    writeln("--%s", line:match "^//(.*)$")
                end
                writeln "--"
            end
            if enums.comments.attached then
                writeln "--"
                writeln("--%s", enums.comments.attached:match "^//(.*)$")
                writeln "--"
            end
        end
        if enums.is_flags_enum then
            write_flags(realname, enums.elements)
        else
            write_enum(realname, enums.elements, new_enums)
        end
        writeln ""
        ::continue::
    end
    for enum_type, elements in pairs(new_enums) do
        write_enum(enum_type, elements)
    end
end

local function write_func(func_meta)
    if func_meta.comments then
        if func_meta.comments.preceding then
            writeln "--"
            for _, line in pairs(func_meta.comments.preceding) do
                writeln("--%s", line:match "^//(.*)$")
            end
            writeln "--"
        end
        if func_meta.comments.attached then
            writeln "--"
            writeln("--%s", func_meta.comments.attached:match "^//(.*)$")
            writeln "--"
        end
    end

    local realname
    local status = {
        i = 1,
        args = func_meta.arguments,
        arguments = {},
    }
    if func_meta.original_class then
        realname = func_meta.name:match("^"..func_meta.original_class.."_([%w]+)$")
        status.i = 2
    else
        realname = func_meta.name:match "^ImGui_([%w]+)$"
    end
    while status.i <= #status.args do
        local type_meta = status.args[status.i]
        local typefunc = special_arg[type_meta.type.declaration]
        if typefunc then
            typefunc(type_meta, status)
        else
            local luatype = lua_type[type_meta.type.declaration]
            if luatype then
                if type_meta.default_value then
                    local default_value = get_default_value(type_meta)
                    if default_value then
                        writeln("---@param %s? %s | `%s`", safe_name(type_meta.name), luatype, default_value)
                    else
                        writeln("---@param %s? %s", safe_name(type_meta.name), luatype)
                    end
                else
                    writeln("---@param %s %s", safe_name(type_meta.name), luatype)
                end
                status.arguments[#status.arguments+1] = safe_name(type_meta.name)
            else
                error(string.format("undefined lua type `%s`", type_meta.type.declaration))
            end
        end
        status.i = status.i + 1
    end
    if func_meta.return_type.declaration ~= "void" then
        local typefunc = special_ret[func_meta.return_type.declaration]
        if typefunc then
            typefunc(func_meta)
        else
            local luatype = lua_type[func_meta.return_type.declaration]
            if not luatype then
                error(string.format("undefined lua type `%s`", func_meta.return_type.declaration))
            end
            writeln("---@return %s", luatype)
        end
        for _, type_meta in ipairs(func_meta.arguments) do
            if type_meta.type then
                local typefunc = return_type[type_meta.type.declaration]
                if typefunc then
                    typefunc(type_meta)
                end
            end
        end
    end
    if func_meta.original_class then
        writeln("function %s.%s(%s) end", func_meta.original_class, realname, table.concat(status.arguments, ", "))
    else
        writeln("function ImGui.%s(%s) end", realname, table.concat(status.arguments, ", "))
    end
    writeln ""
    return realname
end

local function write_structs(struct_funcs)
    writeln("---@alias ImGui.KeyChord ImGui.Key | ImGui.Mod")
    writeln ""
    writeln("---@alias ImTextureID integer")
    writeln ""
    writeln("---@alias ImGuiID integer")
    writeln ""
    local lst <const> = {
        "ImVec2",
        "ImGuiViewport",
        "ImGuiIO",
    }
    for _, name in ipairs(lst) do
        types.decode_docs(name, struct_funcs[name] or {}, writeln, write_func)
    end
end

local function get_funcs()
    local funcs = {}
    local struct_funcs = {}
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
                funcs[#funcs+1] = func_meta
            end
        end
    end
    return funcs, struct_funcs
end

writeln "---@meta imgui"
writeln ""
writeln "--"
writeln "-- Automatically generated file; DO NOT EDIT."
writeln "--"
writeln ""
writeln "---@class ImGui"
writeln "local ImGui = {}"
writeln ""
write_flags_and_enums()
writeln ""
local funcs, struct_funcs = get_funcs()
write_structs(struct_funcs)
for _, func_meta in ipairs(funcs) do
    write_func(func_meta)
end
