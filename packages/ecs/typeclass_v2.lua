local interface = require "interface"
local fs = require "filesystem"
local pm = require "antpm"
local createschema = require "schema"

local current_package
local function getCurrentPackage()
	return current_package
end
local function setCurrentPackage(package)
	current_package = package
end

local function load_impl(files, ecs)
    local modules = {}
    for _, file in ipairs(files) do
        local path = fs.path(file)
        local module, err = fs.loadfile(path, 't', pm.loadenv(path:package_name()))
        if not module then
            error(("module '%s' load failed:%s"):format(file:string(), err))
        end
        modules[#modules+1] = {path:package_name(),module}
    end
    for _, m in ipairs(modules) do
        setCurrentPackage(m[1])
        m[2](ecs)
    end
end

local function load_ecs(name)
    local loaded = {}
    local function loader(packname, filename)
        local f = fs.loadfile(fs.path "/pkg" / packname / filename)
        return f
    end
    local parser = interface.new(loader)
    local function load_package(packname)
        if loaded[packname] then
            return false
        end
        loaded[packname] = true
        parser:load(packname, "package.ecs")
        return true
    end
    load_package(name)
    while true do
        local errlst = parser:check_depend()
        if #errlst == 0 then
            break
        end
        local ok = false
        for _, fullname in ipairs(errlst) do
            local packname = fullname:match "^[^:]*:([^|]*)|.*$"
            if load_package(packname) then
                ok = true
            end
        end
        if not ok then
            for _, fullname in ipairs(errlst) do
                error(string.format("Not found: %s (in %s)", fullname, name))
            end
        end
    end
    return parser
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

local function decl_basetype(schema)
	schema:primtype("ant.ecs", "tag", true)
	schema:primtype("ant.ecs", "entityid", -1)
	schema:primtype("ant.ecs", "int", 0)
	schema:primtype("ant.ecs", "real", 0.0)
	schema:primtype("ant.ecs", "string", "")
	schema:primtype("ant.ecs", "boolean", false)
end

local function splitname(fullname)
    return fullname:match "^([^|]*)|(.*)$"
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


local function singleton_solve(w)
	local class = w._class
	for name in pairs(class.singleton) do
		local ti = class.component[name]
		if not ti then
			error(("singleton `%s` is not defined in component"):format(name))
		end
		if not ti.type and ti.multiple then
			error(("singleton `%s` does not support multiple component"):format(name))
		end
		if class.unique[name] then
			error(("singleton `%s` does not support unique component"):format(name))
		end
		class.unique[name] = true
	end
end

local function interface_solve(w)
	local class = w._class
	local interface = w._interface
	for package, o in pairs(class.interface) do
		for name, v in pairs(o) do
			 setmetatable(interface[package.."|"..name], {__index = v.method})
		end
	end
end

local function importAll(w, class, policies, systems)
	local cut = {
		policy = {},
		system = {},
		transform = {},
		singleton = {},
		interface = {},
		component = class.component,
		unique = {},
		pipeline = class.pipeline,
	}
	w._class = cut
	w._interface = dyntable()
    local import = {}
    for _, objname in ipairs {"system","policy","transform","singleton","interface"} do
        import[objname] = function (name)
            if cut[objname][name] then
                return
            end
            local v = class[objname][name]
            if not v then
                error(("invalid %s name: `%s`."):format(objname, name))
            end
            cut[objname][name] = v
            log.info("Import  ", objname, name)
            if v.require_system then
                for _, k in ipairs(v.require_system) do
                    import.system(k)
                end
            end
            if v.require_policy then
                for _, k in ipairs(v.require_policy) do
                    import.policy(k)
                end
            end
            if v.require_transform then
                for _, k in ipairs(v.require_transform) do
                    import.transform(k)
                end
            end
            if v.require_singleton then
                for _, k in ipairs(v.require_singleton) do
                    import.singleton(k)
                end
            end
            if v.require_interface then
                for _, k in ipairs(v.require_interface) do
                    import.interface(k)
                end
            end
            if objname == "policy" and v.unique_component then
                for _, k in ipairs(v.unique_component) do
                    cut.unique[k] = true
                end
            end
        end
    end
	for _, k in ipairs(policies) do
		import.policy(k)
	end
	for _, k in ipairs(systems) do
		import.system(k)
	end
	return cut
end

return function (w, policies, systems, name, loader)
    local data = load_ecs(name)
    
	local schema_data = {}
	local schema = createschema(schema_data)
	local class = { component = schema_data.map, singleton = {}, pipeline = {} }
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
				log.info("Register", #what<8 and what.."  " or what, package .. "|" .. name)
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
		setter = { "input", "output", "require_interface" },
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
	ecs.resource_component = function (name)
		local c = ecs.component_alias(name, "string")
		c._object.resource = true
		return c
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
	ecs.pipeline = function (name)
		local r = class.pipeline[name]
		if r == nil then
			log.info("Register", "pipeline", name)
			r = {name = name}
			setmetatable(r, {
				__call = function(_,v)
					if r.value then
						error(("duplicate pipleline `%s`."):format(name))
					end
					r.value = v
					return r
				end,
			})
			class.pipeline[name] = r
		end
		return r
	end
    ecs.import = function ()
    end
    decl_basetype(schema)
    load_impl(data.implement, ecs)

    local cut = importAll(w, data, policies, systems)
    local newclass = {}
    for _, objname in ipairs {"system"} do
        local class_ = {}
        newclass[objname] = class_
        for fullname, o in pairs(cut[objname]) do
            local packname, name = splitname(fullname)
            tableAt(class_, packname)[name] = o
        end
        cut[objname] = nil
    end
    for k, v in pairs(cut) do
        newclass[k] = v
    end
    w._class = newclass

	require "component".solve(schema_data)
	require "policy".solve(w)
	singleton_solve(w)
    interface_solve(w)
    
    print "ok"
end
