local builtin_decode <const> = {
    ["bool"] = "boolean",
    ["int"] = "integer",
    ["unsigned int"] = "integer",
    ["float"] = "number",
    ["void*"] = "lightuserdata",
    ["ImDrawData*"] = "lightuserdata",
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
            local builtin = builtin_decode[field.type.declaration]
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
        local builtin = builtin_decode[meta.type.declaration]
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

local function decode_func(name, writeln, what)
    local meta = types[name]
    if meta then
        if meta.kind == "struct" then
            local fieldn = #meta.fields
            writeln("    lua_createtable(L, 0, %d);", fieldn)
            for _, field in ipairs(meta.fields) do
                if fieldn > 4 then
                    writeln ""
                end
                decode_func(field.type.declaration, writeln, what.."."..field.name)
                writeln("    lua_setfield(L, -2, %q);", field.name)
            end
            return
        end
        name = meta.type.declaration
    end
    local builtin = builtin_decode[name]
    assert(builtin ~= nil, name)
    writeln("    lua_push%s(L, %s);", builtin, what)
end

return {
    init = init,
    decode_docs = decode_docs,
    decode_func = decode_func,
}
