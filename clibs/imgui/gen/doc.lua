local status = ...

local types = require "types"

local function writeln(fmt, ...)
    local w = status.docs_file
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

local lua_type <const> = {
    ["const char*"] = "string",
    ["bool"] = "boolean",
    ["float"] = "number",
    ["double"] = "number",
    ["unsigned int"] = "integer",
    ["int"] = "integer",
    ["size_t"] = "integer",
    ["ImGuiKeyChord"] = "ImGuiKeyChord",
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

special_arg["ImFont*"] = function(type_meta, status)
    assert(type_meta.default_value == nil)
    status.arguments[#status.arguments+1] = safe_name(type_meta.name)
    writeln("---@param %s ImFont", safe_name(type_meta.name))
end

special_ret["ImFont*"] = function()
    writeln("---@return ImFont")
end

special_arg["const ImWchar*"] = function(type_meta, status)
    status.arguments[#status.arguments+1] = safe_name(type_meta.name)
    if type_meta.default_value == "NULL" then
        writeln("---@param %s? ImFontRange", safe_name(type_meta.name))
    else
        assert(false)
    end
end

special_ret["const ImWchar*"] = function()
    writeln("---@return ImFontRange")
end

special_arg["const ImGuiWindowClass*"] = function()
    --NOTICE: Ignore ImGuiWindowClass for now.
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

special_arg["void*"] = function (type_meta, status)
    if type_meta.default_value == nil then
        writeln("---@param %s lightuserdata", safe_name(type_meta.name))
        status.arguments[#status.arguments+1] = safe_name(type_meta.name)
    elseif type_meta.default_value == "NULL" then
        writeln("---@param %s lightuserdata?", safe_name(type_meta.name))
        status.arguments[#status.arguments+1] = safe_name(type_meta.name)
    else
        assert(false)
    end
end

special_arg["ImGuiInputTextCallback"] = function (type_meta, context)
    local ud_meta = context.args[context.i + 1]
    if ud_meta and ud_meta.type and ud_meta.type.declaration == "void*" then
        context.i = context.i + 1
        writeln("---@param %s lightuserdata", safe_name(ud_meta.name))
        context.arguments[#context.arguments+1] = safe_name(ud_meta.name)
        return
    end
    assert(false)
end

special_arg["char*"] = function (type_meta, status)
    local size_meta = status.args[status.i + 1]
    if size_meta and size_meta.type and size_meta.type.declaration == "size_t" then
        assert(not type_meta.default_value)
        status.i = status.i + 1
        writeln("---@param %s ImStringBuf | ImStringBuf[] | string[]", safe_name(type_meta.name))
        status.arguments[#status.arguments+1] = safe_name(type_meta.name)
        return
    end
    assert(false)
end

return_type["bool*"] = function (type_meta)
    if type_meta.default_value then
        writeln("---@return boolean | nil %s", safe_name(type_meta.name))
    else
        writeln("---@return boolean %s", safe_name(type_meta.name))
    end
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

local function write_enum(realname, elements)
    local name = string.format("ImGui.%s", realname:match "^ImGui(%a+)$")
    local function fullname(element)
        local fieldname = element.name
        if fieldname:match "^[0-9]" then
            return name.."["..fieldname.."]"
        else
            return name.."."..fieldname
        end
    end
    local lines = {}
    local maxn = 0
    for _, element in ipairs(elements) do
        local fname = fullname(element)
        maxn = math.max(maxn, #fname)
        if element.comments and element.comments.attached then
            lines[#lines+1] = { fname, element.comments.attached:match "^//(.*)$" }
        else
            lines[#lines+1] = { fname }
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
        local fname = element.name
        maxn = math.max(maxn, #fname)
        if element.comments and element.comments.attached then
            lines[#lines+1] = { fname, element.comments.attached:match "^//(.*)$" }
        else
            lines[#lines+1] = { fname }
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
                return string.format("%s { %q }", name, element.name)
            end
        end
    end
end

local function write_comments(comments)
    if comments then
        if comments.preceding then
            writeln "--"
            for _, line in pairs(comments.preceding) do
                writeln("--%s", line:match "^//(.*)$")
            end
            writeln "--"
        end
        if comments.attached then
            writeln "--"
            writeln("--%s", comments.attached:match "^//(.*)$")
            writeln "--"
        end
    end
end

local function write_flags_and_enums()
    for _, v in ipairs(status.flags) do
        write_comments(v.comments)
        write_flags(v.realname, v.elements)
        writeln ""
    end
    for _, v in ipairs(status.enums) do
        write_comments(v.comments)
        write_enum(v.realname, v.elements)
        writeln ""
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
    local context = {
        i = 1,
        args = func_meta.arguments,
        arguments = {},
    }
    if func_meta.original_class then
        realname = func_meta.name:match("^"..func_meta.original_class.."_([%w_]+)$")
        context.i = 2
    else
        realname = func_meta.name:match "^ImGui_([%w_]+)$"
    end
    while context.i <= #context.args do
        local type_meta = context.args[context.i]
        local type_name = type_meta.type.declaration
        local type_func = special_arg[type_name]
        if type_func then
            type_func(type_meta, context)
        elseif status.types[type_name] then
            if type_meta.default_value then
                local default_value = get_default_value(type_meta)
                if default_value then
                    writeln("---@param %s? %s | `%s`", safe_name(type_meta.name), type_name, default_value)
                else
                    writeln("---@param %s? %s", safe_name(type_meta.name), type_name)
                end
            else
                writeln("---@param %s %s", safe_name(type_meta.name), type_name)
            end
            context.arguments[#context.arguments+1] = safe_name(type_meta.name)
        elseif lua_type[type_name] then
            if type_meta.default_value then
                local default_value = get_default_value(type_meta)
                if default_value then
                    writeln("---@param %s? %s | `%s`", safe_name(type_meta.name), lua_type[type_name], default_value)
                else
                    writeln("---@param %s? %s", safe_name(type_meta.name), lua_type[type_name])
                end
            else
                writeln("---@param %s %s", safe_name(type_meta.name), lua_type[type_name])
            end
            context.arguments[#context.arguments+1] = safe_name(type_meta.name)
        else
            error(string.format("undefined lua type `%s`", type_name))
        end
        context.i = context.i + 1
    end
    if func_meta.return_type.declaration ~= "void" then
        local type_name = func_meta.return_type.declaration
        local type_func = special_ret[type_name]
        if type_func then
            type_func(func_meta)
        elseif status.types[type_name] then
            writeln("---@return %s", type_name)
        elseif lua_type[type_name] then
            writeln("---@return %s", lua_type[type_name])
        else
            error(string.format("undefined lua type `%s`", type_name))
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
        writeln("function %s.%s(%s) end", func_meta.original_class, realname, table.concat(context.arguments, ", "))
    else
        writeln("function ImGui.%s(%s) end", realname, table.concat(context.arguments, ", "))
    end
    writeln ""
    return realname
end

local function write_structs()
    writeln "---@alias ImGuiKeyChord ImGui.Key | ImGui.Mod"
    writeln ""
    writeln "---@alias ImTextureID integer"
    writeln ""
    writeln "---@class ImFont"
    writeln ""
    writeln "---@class ImFontRange"
    writeln ""
    writeln "---@class ImStringBuf"
    writeln "local ImStringBuf = {}"
    writeln ""
    writeln "---@param str string"
    writeln "function ImStringBuf:Assgin(str) end"
    writeln ""
    writeln "---@param size integer"
    writeln "function ImStringBuf:Resize(size) end"
    writeln ""
    writeln "---@class ImVec2"
    writeln "---@field x number"
    writeln "---@field y number"
    writeln ""
    for _, v in ipairs(status.types) do
        if status.types[v.type] then
            writeln("---@alias %s %s", v.name, v.type)
        else
            writeln("---@class %s", v.name)
        end
        writeln ""
    end
    for _, v in ipairs(status.structs) do
        types.decode_docs(status, v.name, writeln, write_func)
        local name = v.name
        special_arg[name.."*"] = function(type_meta, status)
            status.arguments[#status.arguments+1] = safe_name(type_meta.name)
            if type_meta.default_value == nil then
                writeln("---@param %s %s", safe_name(type_meta.name), name)
            elseif type_meta.default_value == "NULL" then
                writeln("---@param %s? %s", safe_name(type_meta.name), name)
            else
                assert(false)
            end
        end
        special_arg["const "..name.."*"] = special_arg[name.."*"]
        if v.reference then
            special_ret[name.."*"] = function()
                writeln("---@return %s", name)
            end
        elseif v.mode == "pointer" then
            special_ret[name.."*"] = function()
                writeln("---@return %s?", name)
            end
        elseif v.mode == "const_pointer" then
            special_ret[name.."*"] = function()
                writeln("---@return %s", name)
            end
        else
            assert(false)
        end
    end
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
write_structs()
for _, v in ipairs(status.structs) do
    if v.forward_declaration then
        goto continue
    end
    local name = v.name
    local realname = name:match "^ImGui([%w]+)$" or name:match "^Im([%w]+)$"
    writeln("---@return userdata")
    writeln("---@return %s", name)
    writeln("function ImGui.%s() end", realname)
    writeln ""
    ::continue::
end
writeln "---@param str? string"
writeln "---@return ImStringBuf"
writeln "function ImGui.StringBuf(str) end"
writeln ""
for _, func_meta in ipairs(status.funcs) do
    write_func(func_meta)
end
writeln "return ImGui"
