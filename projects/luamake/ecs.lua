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
            elseif t == "c" then
                components[#components+1] = {name, "c", info.field}
            elseif t == "raw" then
                components[#components+1] = {name, "raw", info.field[1], info.size[1]}
            else
                components[#components+1] = {name, t}
            end
        end
    end
    table.sort(components, function (a, b)
        return a[1] < b[1]
    end)
    return components
end

local components = loadComponents()


local out = {}

local function writefile(filename)
    local f <close> = assert(io.open(filename, "w"))
    f:write(table.concat(out, "\n"))
    out = {}
end

local function write(line)
    out[#out+1] = line
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

do
    write "#pragma once"
    write ""
    write "#include \"ecs/select.h\""
    write "#include \"ecs/component_name.h\""
    write "#include \"ecs/user.h\""
    write "#include <cstdint>"
    write "#include <tuple>"
    write ""
    write "namespace ant_component {"
    write ""
    write "using eid = uint64_t;"
    write "struct REMOVED {};"
    write ""
    for _, info in ipairs(components) do
        local name, type = info[1], info[2]
        if type == "c" then
            local fields = info[3]
            write(("struct %s {"):format(name))
            for _, field in ipairs(fields) do
                local name, typename = field:match "^([%w_]+):(.+)$"
                write(("\t%s %s;"):format(typenames(typename), name))
            end
            write("};")
            write ""
        elseif type == "raw" then
            local field, size = info[3], info[4]
            write(("struct %s {"):format(name))
            write(field:match "^(.-)[ \t\r\n]*$")
            write("};")
            write(("static_assert(sizeof(%s) == %s);"):format(name, size))
            write ""
        elseif type == "tag" then
            write(("struct %s {};"):format(name))
            write ""
        elseif type == "lua" then
            write(("struct %s {};"):format(name))
            write ""
        else
            write(("using %s = %s;"):format(name, typenames(type)))
            write ""
        end
    end
    
    write ""
    write "using _all_ = ::std::tuple<"
    for i = 1, #components-1 do
        local c = components[i]
        write(("    %s,"):format(c[1]))
    end
    write(("    %s"):format(components[#components][1]))
    write ">;"
    write ""
    write "}"
    write ""
    write "namespace component = ant_component;"
    write ""

    write "template <>"
    write "constexpr int ecs::component_id<ant_component::eid> = ecs::COMPONENT::EID;"
    write "template <>"
    write "constexpr int ecs::component_id<ant_component::REMOVED> = ecs::COMPONENT::REMOVED;"
    write "template <typename T>"
    write "    requires (ecs::helper::component_has_v<T, ant_component::_all_>)"
    write "constexpr int ecs::component_id<T> = ecs::helper::component_id_v<T, ant_component::_all_>;"
    write ""

    writefile(component_h .. "/component.hpp")
end
