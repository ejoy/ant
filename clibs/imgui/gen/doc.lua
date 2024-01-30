local AntDir, meta = ...

local w <close> = assert(io.open(AntDir.."/misc/meta/imgui.lua", "wb"))

local function writeln(fmt, ...)
    w:write(string.format(fmt, ...))
    w:write "\n"
end

local KEYWORD <const> = {
    ["repeat"] = "repeat_"
}

local function safe_name(v)
    return KEYWORD[v] or v
end

local lua_type = {
    ["const char*"] = "string",
    ["bool"] = "boolean",
    ["float"] = "number",
    ["double"] = "number",
    ["int"] = "integer",
    ["size_t"] = "integer",
    ["ImGuiID"] = "integer",
    ["ImU32"] = "integer",
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

special_arg["ImVec2"] = function (type_meta, status)
    if type_meta.default_value == nil then
        writeln("---@param %s_x number", type_meta.name)
        writeln("---@param %s_y number", type_meta.name)
    else
        assert(type_meta.default_value == "ImVec2(0.0f, 0.0f)" or type_meta.default_value == "ImVec2(0, 0)", type_meta.default_value)
        writeln("---@param %s_x? number | `0.0`", type_meta.name)
        writeln("---@param %s_y? number | `0.0`", type_meta.name)
    end
    status.arguments[#status.arguments+1] = type_meta.name .. "_x"
    status.arguments[#status.arguments+1] = type_meta.name .. "_y"
end

special_ret["ImVec2"] = function ()
    writeln("---@return number")
    writeln("---@return number")
end

special_arg["bool*"] = function (type_meta, status)
    writeln("---@param %s true | nil", safe_name(type_meta.name))
    status.arguments[#status.arguments+1] = safe_name(type_meta.name)
end

special_arg["size_t*"] = function (type_meta, status)
    writeln("---@param %s integer | nil", safe_name(type_meta.name))
    status.arguments[#status.arguments+1] = safe_name(type_meta.name)
end

special_arg["const char*"] = function (type_meta, status)
    local size_meta = status.args[status.i + 1]
    if size_meta and size_meta.type.declaration == "size_t" then
        assert(not type_meta.default_value)
        assert(size_meta.type.declaration == "size_t")
        status.i = status.i + 1
        writeln("---@param %s string", safe_name(type_meta.name))
        status.arguments[#status.arguments+1] = safe_name(type_meta.name)
        return
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
    assert(not type_meta.default_value)
    assert(not size_meta.default_value)
    assert(size_meta.type.declaration == "size_t")
    status.i = status.i + 1
    writeln("---@param %s string", safe_name(type_meta.name))
    status.arguments[#status.arguments+1] = safe_name(type_meta.name)
end

return_type["bool*"] = function (type_meta)
    writeln("---@return boolean %s", safe_name(type_meta.name))
end

default_type["float"] = function (value)
    return value:match "^(.*)f$"
end

default_type["const char*"] = function (value)
    assert(value == "NULL")
    return nil
end

local function conditionals(t)
    local cond = t.conditionals
    if not cond then
        return true
    end
    assert(#cond == 1)
    cond = cond[1]
    if cond.condition == "ifndef" then
        cond = cond.expression
        if cond == "IMGUI_DISABLE_OBSOLETE_KEYIO" then
            return
        end
        if cond == "IMGUI_DISABLE_OBSOLETE_FUNCTIONS" then
            return
        end
    elseif cond.condition == "ifdef" then
        cond = cond.expression
        if cond == "IMGUI_DISABLE_OBSOLETE_KEYIO" then
            return true
        end
        if cond == "IMGUI_DISABLE_OBSOLETE_FUNCTIONS" then
            return true
        end
    end
    assert(false, t.name)
end

local function write_enum_scope()
    writeln("ImGui.Flags = {}")
    writeln("ImGui.Enum = {}")
    writeln ""
    for _, enums in ipairs(meta.enums) do
        if not conditionals(enums) then
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
        writeln("---@class %s", realname)
        if enums.is_flags_enum then
            local name = realname:match "^ImGui(%a+)Flags$" or realname:match "^Im(%a+)Flags$"
            writeln ""
            writeln("---@alias _%s_Name", realname)
            for _, element in ipairs(enums.elements) do
                if not element.is_internal and conditionals(element) then
                    if element.comments and element.comments.attached then
                        writeln("---| %q # %s", element.name:sub(#realname+2), element.comments.attached:match "^//(.*)$")
                    else
                        writeln("---| %q", element.name:sub(#realname+2))
                    end
                end
            end
            writeln ""
            writeln("---@param flags _%s_Name[]", realname)
            writeln("---@return %s", realname)
            writeln("function ImGui.Flags.%s(flags) end", name)
            lua_type[realname] = realname
            default_type[realname] = function (value)
                local v = math.tointeger(value)
                for _, element in ipairs(enums.elements) do
                    if element.value == v then
                        return string.format("ImGui.Flags.%s { %q }", name, element.name:sub(#realname+2))
                    end
                end
            end
        else
            local name = realname:match "^ImGui(%a+)$"
            writeln ""
            writeln("---@class _%s_Name", realname)
            local mark = {}
            for _, element in ipairs(enums.elements) do
                if not element.is_internal and not element.is_count and conditionals(element) then
                    local fieldname = element.name:sub(#realname+2)
                    if fieldname:match "^[0-9]" then
                        fieldname = "["..fieldname.."]"
                    end
                    if not mark[fieldname] then
                        mark[fieldname] = true
                        if element.comments and element.comments.attached then
                            writeln("---@field %s %s # %s", fieldname, realname, element.comments.attached:match "^//(.*)$")
                        else
                            writeln("---@field %s %s", fieldname, realname)
                        end
                    end
                end
            end
            writeln("ImGui.Enum.%s = {}", name)
            lua_type[realname] = realname
            default_type[realname] = function (value)
                local v = math.tointeger(value)
                for _, element in ipairs(enums.elements) do
                    if element.value == v then
                        local fieldname = element.name:sub(#realname+2)
                        if fieldname:match "^[0-9]" then
                            fieldname = "["..fieldname.."]"
                        else
                            fieldname = "."..fieldname
                        end
                        return string.format("ImGui.Enum.%s%s", name, fieldname)
                    end
                end
            end
        end
        writeln ""
        ::continue::
    end
end

local function write_type_scope()
    writeln("---@alias ImGuiKeyChord ImGuiKey")
end

local function write_func(func_meta)
    local realname = func_meta.name:match "^ImGui_([%w]+)$"

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
    local status = {
        i = 1,
        args = func_meta.arguments,
        arguments = {},
    }
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
            local typefunc = return_type[type_meta.type.declaration]
            if typefunc then
                typefunc(type_meta)
            end
        end
    end
    writeln("function ImGui.%s(%s) end", realname, table.concat(status.arguments, ", "))
    writeln ""
    return realname
end

local allow = require "allow"

local function write_func_scope()
    local funcs = {}
    allow.init()
    for _, func_meta in ipairs(meta.functions) do
        if allow.query(func_meta) then
            funcs[#funcs+1] = write_func(func_meta)
        end
    end
    return funcs
end

writeln "---@meta imgui"
writeln ""
writeln "--"
writeln "-- Automatically generated file; DO NOT EDIT."
writeln "--"
writeln ""
writeln "local ImGui = {}"
writeln ""
write_enum_scope()
writeln ""
write_type_scope()
writeln ""
write_func_scope()
writeln "return ImGui"
