local AntDir, meta = ...


local w <close> = assert(io.open(AntDir.."/misc/meta/imgui.lua", "wb"))

local function writeln(fmt, ...)
    w:write(string.format(fmt, ...))
    w:write "\n"
end

local lua_type = {
    ["const char*"] = "string",
    ["bool"] = "boolean",
    ["float"] = "number",
    ["int"] = "integer",
    ["ImGuiID"] = "integer",
    ["ImU32"] = "integer",
    ["ImGuiTableSortSpecs*"] = "lightuserdata",
}

local special_type = {}
local return_type = {}
local default_type = {}

special_type["ImVec2"] = function (type_meta, arguments)
    assert(type_meta.default_value == "ImVec2(0.0f, 0.0f)")
    writeln("---@param %s_x? number | `0.0`", type_meta.name)
    writeln("---@param %s_y? number | `0.0`", type_meta.name)
    arguments[#arguments+1] = type_meta.name .. "_x"
    arguments[#arguments+1] = type_meta.name .. "_y"
end

special_type["bool*"] = function (type_meta, arguments)
    writeln("---@param %s true | nil", type_meta.name)
    arguments[#arguments+1] = type_meta.name
end

return_type["bool*"] = function (type_meta)
    writeln("---@return boolean %s", type_meta.name)
end

default_type["float"] = function (value)
    return value:match "^(.*)f$"
end

local function get_default_value(type_meta)
    local func = default_type[type_meta.type.declaration]
    if func then
        return func(type_meta.default_value)
    end
    return type_meta.default_value
end

local function write_enum_scope()
    writeln("ImGui.Flags = {}")
    writeln("ImGui.Enum = {}")
    writeln ""
    for _, enums in ipairs(meta.enums) do
        if enums.conditionals then
            goto continue
        end
        local realname = enums.name:match "(.-)_?$"
        lua_type[realname] = realname
        default_type[realname] = function (value)
            local v = math.tointeger(value)
            for _, element in ipairs(enums.elements) do
                if element.value == v then
                    return string.format("ImGui.Flags.%s { %q }", realname:match "^ImGui(%a+)Flags$", element.name:sub(#realname+2))
                end
            end
        end
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
            writeln ""
            writeln("---@alias _%s_Name", realname)
            for _, element in ipairs(enums.elements) do
                if not element.is_internal then
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
            writeln("function ImGui.Flags.%s(flags) end", realname:match "^ImGui(%a+)Flags$")
        else
            --TODO
        end
        writeln ""
        ::continue::
    end
end

local function write_func(func_meta)
    local realname = func_meta.name:match "^ImGui_([%w]+)$"
    local arguments = {}

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
    for _, type_meta in ipairs(func_meta.arguments) do
        local typefunc = special_type[type_meta.type.declaration]
        if typefunc then
            typefunc(type_meta, arguments)
            goto continue
        end
        local luatype = lua_type[type_meta.type.declaration]
        if luatype then
            if type_meta.default_value then
                writeln("---@param %s? %s | `%s`", type_meta.name, luatype, get_default_value(type_meta))
            else
                writeln("---@param %s %s", type_meta.name, luatype)
            end
            arguments[#arguments+1] = type_meta.name
            goto continue
        end
        error(string.format("undefined lua type `%s`", type_meta.type.declaration))
        ::continue::
    end
    if func_meta.return_type.declaration ~= "void" then
        local luatype = lua_type[func_meta.return_type.declaration]
        if not luatype then
            error(string.format("undefined lua type `%s`", func_meta.return_type.declaration))
        end
        writeln("---@return %s", luatype)
        for _, type_meta in ipairs(func_meta.arguments) do
            local typefunc = return_type[type_meta.type.declaration]
            if typefunc then
                typefunc(type_meta)
            end
        end
    end
    writeln("function ImGui.%s(%s) end", realname, table.concat(arguments, ", "))
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
write_func_scope()
writeln "return ImGui"
