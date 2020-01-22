local typeclass = require "typeclass"
local system = require "system"
local component = require "component"
local policy = require "policy"
local createschema = require "schema"
local event = require "event"
local datalist = require "datalist"

local component_init = component.init
local component_delete = component.delete

local function splitName(fullname, import)
    local package, name = fullname:match "^([^|]*)|(.*)$"
    if package then
        import(package)
        return name
    end
    return fullname
end

local function tableDelete(t, l)
    local delete = {}
    for k in pairs(t) do
        if not l[k] then
            delete[k] = true
        end
    end
    for k in pairs(delete) do
        t[k] = nil
    end
end

local function init_modules(w, packages, loader)
    -- local policies = config.policy
    -- local systems = config.system
    local class = {}
    local imported = {}
    local reg
    local function import_package(name)
        if imported[name] then
            return false
        end
        imported[name] = true
        table.insert(class.packages, 1, name)
        local modules = assert(loader(name) , "load module " .. name .. " failed")
        if type(modules) == "table" then
            for _, m in ipairs(modules) do
                m(reg)
            end
        else
            modules(reg)
        end
        table.remove(class.packages, 1)
        return true
    end
    reg = typeclass(w, import_package, class)
    w.import = function(_, name)
        return import_package(name)
    end

    local policycut = {}
    local systemcut = {}
    local import_policy
    local import_system
    function import_system(k)
        local name = splitName(k, import_package)
        if systemcut[name] then
            return
        end
        systemcut[name] = true
        local v = class.system[name]
        if not v then
            error(("invalid system name: `%s`."):format(name))
        end
        if v.require_package then
            for _, name in ipairs(v.require_package) do
                import_package(name)
            end
        end
        if v.require_system then
            for _, k in ipairs(v.require_system) do
                import_system(k)
            end
        end
        if v.require_policy then
            for _, k in ipairs(v.require_policy) do
                import_policy(k)
            end
        end
    end

    function import_policy(k)
        local name = splitName(k, import_package)
        if policycut[name] then
            return
        end
        policycut[name] = true
        local v = class.policy[name]
        if not v then
            error(("invalid policy name: `%s`."):format(name))
        end
        if v.require_package then
            for _, name in ipairs(v.require_package) do
                import_package(name)
            end
        end
        if v.require_system then
            for _, k in ipairs(v.require_system) do
                import_system(k)
            end
        end
        if v.require_policy then
            for _, k in ipairs(v.require_policy) do
                import_policy(k)
            end
        end
    end
    for _, p in ipairs(packages) do
        import_package(p)
    end
    for k, _ in pairs(class.policy) do
        import_policy(k)
    end
    tableDelete(class.policy, policycut)
    tableDelete(class.system, systemcut)
    --tableDelete(class.component, componentcut)
    return class
end

local function sourceinfo()
    local info = debug.getinfo(3, "Sl")
    return string.format("%s(%d)", info.source, info.currentline)
end

local function keys(tbl)
    local k = {}
    for _, v in ipairs(tbl) do
        k[v] = true
    end
    return k
end

local function gen_set(c, setter)
    local keys = keys(setter)
    return function(_, key)
        if not keys[key] then
            error("Invalid set " .. key)
        end
        return function(value)
            local list = c[key]
            if list == nil then
                list = { value }
                c[key] = list
            else
                table.insert(list, value)
            end
        end
    end
end

local function gen_method(c, callback)
    if callback then
        callback = keys(callback)
    end
    return function(_, key, func)
        if type(func) ~= "function" then
            error("Method should be a function")
        end
        if callback and callback[key] == nil then
            error("Invalid callback function " .. key)
        end
        if c.source[key] ~= nil then
            error("Method " .. key .. " has already defined at " .. c.source[key])
        end
        c.source[key] = sourceinfo()
        rawset(c.method, key, func)
    end
end

local current_package = {}
local function getCurrentPackage()
    return current_package[#current_package]
end
local function pushCurrentPackage(name)
    current_package[#current_package+1] = name
end
local function popCurrentPackage()
    current_package[#current_package] = nil
end
local deferCurrentPackage = setmetatable({}, {__close=popCurrentPackage})



local function decl_basetype(schema)
    schema:primtype("ant.ecs", "tag", "boolean", true)
    schema:primtype("ant.ecs", "entityid", -1)
    schema:primtype("ant.ecs", "int", 0)
    schema:primtype("ant.ecs", "real", 0.0)
    schema:primtype("ant.ecs", "string", "")
    schema:primtype("ant.ecs", "boolean", false)
end

local function tableAt(t, k)
    local v = t[k]
    if v then
        return v
    end
    v = {}
    t[k] = v
    return v
end

local function dyntable()
    return setmetatable({}, {__index=function(t,k)
        local o = {}
        t[k] = o
        return o
    end})
end

local function importAll(w, ecs, class, packages, loader)
    local cut = {
        policy = {},
        system = {},
        transform = {},
        singleton = {},
        interface = {},
        component = class.component,
        unique = {},
    }
    w._class = cut
    w._interface =  dyntable()
    -- local policies = config.policy
    -- local systems  = config.system
    local imported = {}
    local importPolicy
    local importSystem
    local importComponent
    local importTransform
    local importSingleton
    local importInterface
    local importPackage
    ecs.import = function(name)
        pushCurrentPackage(name)
        importPackage(name)
        popCurrentPackage()
    end
    function importPackage(name)
        if imported[name] then
            return
        end
        imported[name] = true
        local modules = assert(loader(name) , "load module " .. name .. " failed")
        if type(modules) == "table" then
            for _, m in ipairs(modules) do
                m(ecs)
            end
        else
            modules(ecs)
        end
    end
    for _, k in ipairs(packages) do
        pushCurrentPackage(k)
        importPackage(k)
    end
    
    --interface
    local interfaces = w._class.interface
    for p,interfaces in pairs(class.interface) do
        for n,int in pairs(interfaces) do
            interfaces[n] = int
        end
    end
    --policies
    local policies = w._class.policy
    for p,policy_tbl in pairs(class.policy) do
        for n,policy in pairs(policy_tbl) do
            policies[n] = policy
        end
    end
    --singleton
    w._class.singleton = class.singleton
    --system
    local systems = w._class.system
    for p,system_tbl in pairs(class.system) do
        for n,system in pairs(system_tbl) do
            systems[n] = system
        end
    end
    --transform
    local transforms = w._class.transform
    for p,transform_tbl in pairs(class.transform) do
        for n,transform in pairs(transform_tbl) do
            transforms[n] = transform
        end
    end
    -- assert(false)
end

local function typeclass(w, packages, loader)
    local schema_data = {}
    local schema = createschema(schema_data)
    local class = { component = schema_data.map, singleton = {} }
    local ecs = { world = w }
    local function register(args)
        local what = args.type
        local class_set = {}
        local class_data = class[what] or dyntable()
        class[what] = class_data
        ecs[what] = function(name)
            local package = getCurrentPackage()
            local r = tableAt(class_set, package)[name]
            if r == nil then
                log.info("Register", what, package .. "|" .. name)
                local c = { name = name, method = {}, source = {}, defined = sourceinfo(), package = package }
                class_data[package][name] = c
                r = {}
                setmetatable(r, {
                    __index = args.setter and gen_set(c, args.setter),
                    __newindex = gen_method(c, args.callback),
                })
                tableAt(class_set, package)[name] = r
            end
            return r
        end
    end
    register {
        type = "system",
        setter = { "require_policy", "require_system", "require_singleton", "require_interface" },
    }
    register {
        type = "transform",
        setter = { "input", "output" },
        callback = { "process" },
    }
    register {
        type = "policy",
        setter = { "require_component", "require_transform", "require_system", "require_policy", "unique_component" },
        callback = { },
    }
    register {
        type = "interface",
        setter = { "require_system", "require_interface" },
    }
    ecs.component = function (name)
        return schema:type(getCurrentPackage(), name)
    end
    ecs.component_alias = function (name, ...)
        return schema:typedef(getCurrentPackage(), name, ...)
    end
    ecs.tag = function (name)
        ecs.component_alias(name, "tag")
    end
    ecs.singleton = function (name)
        return function (dataset)
            if class.singleton[name] then
                error(("singleton `%s` duplicate definition"):format(name))
            end
            class.singleton[name] = {dataset}
        end
    end
    decl_basetype(schema)
    importAll(w, ecs, class, packages, loader)
end


local function run(world_meta,config,packages)
    local w = setmetatable({
        args = config,
        _schema = {},
        _entity = {},   -- entity id set
        _entity_id = 0,
        _set = setmetatable({}, { __mode = "kv" }),
        _removed = {},  -- A list of { eid, component_name, component } / { eid, entity }
        _switchs = {},  -- for enable/disable
    }, world_meta)
    w.sub = function()
    end

    typeclass(w, packages,config.loader or require "packageloader")

    -- local class = init_modules(w,packages,require "packageloader")
    -- w._class = class
    return w
end

return {
    run = run,
}