local AntDir, component_h = ...
local ecs_components = dofile(AntDir.."/clibs/ecs/ecs_components.lua")

local argn = select("#", ...)
if argn < 3 then
    print [[
at least 3 argument:
ecs.lua AntDir component.h package1, package2, ...
package1 and package2 are path to find *.ecs file
    ]]
    return
end

local packages = {}
for i = 3, select('#', ...) do
    packages[i-2] = select(i, ...)
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
                for file in fs.pairs_r(pkg) do
                    if file:extension() == ".ecs" then
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
    component_h,
    "ant_component",
    "ecs/user.h",
    components
)
