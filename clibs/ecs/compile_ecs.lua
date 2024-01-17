local function ecs_components(output, namespace, userheader, components)
    local out = {}
    local function writefile(filename)
        local f <close> = assert(io.open(filename, "w"))
        f:write(table.concat(out, "\n"))
        out = {}
    end
    local function write(line)
        out[#out+1] = line
    end
    write "#pragma once"
    write ""
    write "#include \"ecs/select.h\""
    write(("#include \"%s\""):format(userheader))
    write "#include <cstdint>"
    write "#include <tuple>"
    write ""
    write(("namespace %s {"):format(namespace))
    write ""
    write "using eid = uint64_t;"
    write ""
    write "struct REMOVED {};"
    write ""
    for _, info in ipairs(components) do
        local name, type = info[1], info[2]
        if type == "c" then
            local fields = info[3]
            write(("struct %s {"):format(name))
            for _, field in ipairs(fields) do
                write(("\t%s %s;"):format(field[1], field[2]))
            end
            write("};")
            write ""
        elseif type == "raw" then
            local size = info[3]
            write(("struct %s { uint8_t raw[%d]; }"):format(name, size))
            write ""
        elseif type == "tag" then
            write(("struct %s {};"):format(name))
            write ""
        elseif type == "lua" then
            write(("struct %s { unsigned int lua_object; };"):format(name))
            write ""
        elseif type == "int" then
            local field = info[2]
            write(("using %s = %s;"):format(name, field))
            write ""
        end
    end
    write "using _all_ = ::std::tuple<"
    for i = 1, #components-1 do
        local c = components[i]
        write(("\t%s,"):format(c[1]))
    end
    write(("\t%s"):format(components[#components][1]))
    write ">;"
    write ""
    write "}"
    write ""
    write(("namespace component = %s;"):format(namespace))
    write ""
    write "template <>"
    write "constexpr inline auto ecs::component_id<component::eid> = ecs::COMPONENT::EID;"
    write "template <>"
    write "constexpr inline auto ecs::component_id<component::REMOVED> = ecs::COMPONENT::REMOVED;"
    write "template <typename T>"
    write "    requires (ecs::helper::component_has_v<T, component::_all_>)"
    write "constexpr inline auto ecs::component_id<T> = ecs::helper::component_id_v<T, component::_all_>;"
    write ""
    writefile(output)
end

local argn = select("#", ...)
if argn < 2 then
    print [[
at least 2 argument:
ecs.lua component.h package1, package2, ...
package1 and package2 are path to find *.ecs file
    ]]
    return
end
local component_h = select(1, ...)
local packages = {}
for i = 2, select('#', ...) do
    packages[i-1] = select(i, ...)
end

local fs = require "bee.filesystem"

local function createEnv(class)
    local function dummy()
        return function ()
            local o = {}
            local mt = {}
            function mt:__index()
                return function ()
                    return o
                end
            end
            return setmetatable(o, mt)
        end
    end
    local function object(object_name)
        local c = {}
        class[object_name] = c
        return function (name)
            local cc = {}
            c[name] = cc

            local o = {}
            local mt = {}
            function mt:__index(key)
                return function (value)
                    if cc[key] then
                        table.insert(cc[key], value)
                    else
                        cc[key] = {value}
                    end
                    return o
                end
            end
            return setmetatable(o, mt)
        end
    end
    return {
        import = function() end,
        import_feature = function() end,
        feature = dummy(),
        pipeline = dummy(),
        system = dummy(),
        policy = dummy(),
        component = object "component",
    }
end

local TYPENAMES <const> = {
    int = "int32_t",
    int64 = "int64_t",
    dword = "uint32_t",
    word = "uint16_t",
    byte = "uint8_t",
    float = "float",
    userdata = "int64_t",
}

local function typenames(v)
    local _, ud = v:match "^([^|]+)|(.*)$"
    if ud then
        return ud
    end
    return assert(TYPENAMES[v], ("Invalid %s"):format(v))
end

local function loadComponents()
    local class = {}
    local env = createEnv(class)
    local function eval(filename)
        assert(loadfile(filename:string(), "t", env))()
    end
    for _, pkgs in ipairs(packages) do
        for pkg in fs.pairs(pkgs) do
            if not pkg:string():match "%.DS_Store" then
                for file in fs.pairs(pkg, "r") do
                    if file:equal_extension "ecs" then
                        eval(file)
                    end
                end
            end
        end
    end

    local components = {}
    for name, info in pairs(class.component) do
        if not info.type then
            components[#components+1] = {name, "tag"}
        else
            local t = info.type[1]
            if t == "lua" then
                --components[#components+1] = {name, "lua"}
            elseif t == "c" then
                local fields = {}
                for _, field in ipairs(info.field) do
                    local fieldname, typename = field:match "^([%w_]+):(.+)$"
                    fields[#fields+1] = { typenames(typename), fieldname }
                end
                components[#components+1] = {name, "c", fields}
            elseif t == "raw" then
                components[#components+1] = {name, "raw", info.size[1]}
            else
                components[#components+1] = {name, "int", typenames(t)}
            end
        end
    end
    table.sort(components, function (a, b)
        return a[1] < b[1]
    end)
    return components
end

local components = loadComponents()

ecs_components(
    component_h .. "/component.hpp",
    "ant_component",
    "ecs/user.h",
    components
)
