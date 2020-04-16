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
    local parser
    local loaded = {}
    local function load_package(packname)
        if not loaded[packname] then
            loaded[packname] = true
            parser:load(packname, "package.ecs")
        end
    end
    local function loader(packname, filename)
        local f = fs.loadfile(fs.path "/pkg" / packname / filename)
        return f
    end
    parser = interface.new(loader)
    load_package(name)
    parser:check()
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

local function sortpairs(t)
    local sort = {}
    for k in pairs(t) do
        sort[#sort+1] = k
    end
    table.sort(sort)
    local n = 1
    return function ()
        local k = sort[n]
        if k == nil then
            return
        end
        n = n + 1
        return k, t[k]
    end
end

local check_map = {
	require_system = "system",
	require_interface = "interface",
	require_policy = "policy",
	require_transform = "transform",

	require_singleton = "singleton",
	require_component = "component",
	unique_component = "component",
	input = "component",
	output = "component",
}

local function importAll(class, policies, systems)
	local res = {
		policy = {},
		system = {},
		transform = {},
		singleton = {},
		interface = {},
		component = {},
		unique = {},
        implement = {},
    }
    local mark_implement = {}
    local import = {}
    for _, objname in ipairs {"system","policy","transform","singleton","interface","component"} do
        import[objname] = function (name)
            if res[objname][name] then
                return
            end
            local v = class[objname][name]
            if not v then
                error(("invalid %s name: `%s`."):format(objname, name))
            end
            log.info("Import  ", objname, name)
            res[objname][name] = v
            for _, impl in ipairs(v.implement) do
                local file = "/pkg/"..v.implement.packname.."/"..impl
                if not mark_implement[file] then
                    mark_implement[file] = true
                    res.implement[#res.implement+1] = file
                end
            end
			for what, attrib in sortpairs(check_map) do
				if v[what] then
					for _, k in ipairs(v[what]) do
						import[attrib](k)
					end
				end
			end
            if objname == "policy" and v.unique_component then
                for _, k in ipairs(v.unique_component) do
                    res.unique[k] = true
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
	return res
end

return function (w, policies, systems, packname, implement)
	local schema_data = {}
	local schema = createschema(schema_data)
    decl_basetype(schema)
    local data = load_ecs(packname)
	local declaration = importAll(data, policies, systems)

	local class = {}
	local ecs = { world = w }
	w._class = {}
	w._interface = dyntable()

	local function register(what)
		local class_set = {}
		local class_data = {}
		class[what] = class_data
		ecs[what] = function(name)
			local package = getCurrentPackage()
			local fullname = package .. "|" .. name
			local r = class_set[fullname]
			if r == nil then
				log.info("Register", #what<8 and what.."  " or what, fullname)
				r = {}
				local decl = declaration[what][fullname]
				if not decl then
					--error(("%s `%s` in `%s` is not defined."):format(what, name, package))
					setmetatable(r, {
						__index = function() return function() end end,
						__newindex = function() end,
					})
				else
					if decl.method then
						local c = { name = name, method = {}, source = {}, defined = sourceinfo(), package = package }
						class_data[fullname] = c
						setmetatable(r, {
							__index = function() return function() end end,
							__newindex = gen_method(c, decl.method),
						})
					else
						setmetatable(r, {
							__index = function() return function() end end,
							__newindex = function() error(("%s `%s` in `%s` has no method."):format(what, name, package)) end,
						})
					end
				end
				class_set[fullname] = r
			end
			return r
		end
	end
	register "system"
	register "transform"
	register "policy"
	register "interface"
	local class_singleton = {}
	local class_pipeline = {}
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
			if class_singleton[name] then
				error(("singleton `%s` duplicate definition"):format(name))
			end
			class_singleton[name] = {dataset}
		end
	end
	ecs.pipeline = function (name)
		local r = class_pipeline[name]
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
			class_pipeline[name] = r
		end
		return r
	end
    ecs.import = function ()
    end
    load_impl(declaration.implement, ecs)
    load_impl(implement, ecs)

    for _, objname in ipairs {"system","policy","interface","transform"} do
        local newclass = {}
        for fullname, o in pairs(declaration[objname]) do
            local packname, name = splitname(fullname)
			tableAt(newclass, packname)[name] = o
			if o.method then
				local funcmap = class[objname][fullname].method
				local newmethod = {}
				for i = 1, #o.method do
					local name = o.method[i]
					newmethod[name] = funcmap[name]
				end
				o.method = newmethod
			end
        end
		w._class[objname] = newclass
    end
	w._class.component = schema_data.map
	w._class.pipeline = class_pipeline
	w._class.singleton = class_singleton
	w._class.unique = declaration.unique

	require "component".solve(schema_data)
	require "policy".solve(w)
	singleton_solve(w)
    interface_solve(w)
end
