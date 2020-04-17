local interface = require "interface"
local fs = require "filesystem"
local pm = require "antpm"
local createschema = require "schema"

local current_package = {}
local function getCurrentPackage()
	return current_package[#current_package]
end
local function pushCurrentPackage(package)
	current_package[#current_package+1] = package
end
local function popCurrentPackage()
	current_package[#current_package] = nil
end

local imported = {}
local function import_impl(file, ecs)
	if imported[file] then
		return
	end
	imported[file] = true
	local path = fs.path(file)
	local packname = path:package_name()
	local module, err = fs.loadfile(path, 't', pm.loadenv(packname))
	if not module then
		error(("module '%s' load failed:%s"):format(file, err))
	end
	pushCurrentPackage(packname)
	module(ecs)
	popCurrentPackage()
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
        local f = assert(fs.loadfile(fs.path "/pkg" / packname / filename))
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

local function gen_method(c)
	local callback = keys(c.methodname)
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
	require_component = "component",
	unique_component = "component",
	input = "component",
	output = "component",
}

local function create_importor(w, ecs, declaration)
	local import_component = {}
    local import = {}
    for _, objname in ipairs {"system","policy","transform","interface","component"} do
		if objname ~= "component" then
			w._class[objname] = {}
		end
		import[objname] = function (name)
			local res = objname == "component" and import_component or w._class[objname]
            if res[name] then
                return
            end
            local v = declaration[objname][name]
            if not v then
                error(("invalid %s name: `%s`."):format(objname, name))
            end
            log.info("Import  ", objname, name)
			res[name] = v
			for what, attrib in sortpairs(check_map) do
				if v[what] then
					for _, k in ipairs(v[what]) do
						import[attrib](k)
					end
				end
			end
            if objname == "policy" and v.unique_component then
                for _, k in ipairs(v.unique_component) do
                    w._class.unique[k] = true
                end
            end
			if v.implement then
				for _, impl in ipairs(v.implement) do
					import_impl("/pkg/"..v.packname.."/"..impl, ecs)
				end
			end
        end
	end
	return import
end

local function solve_object(w, type, fullname)
	local o = w._class[type][fullname]
	if o and o.methodname then
		for _, name in ipairs(o.methodname) do
			if not o.method[name] then
				error(("`%s`'s `%s` method is not defined."):format(fullname, name))
			end
		end
	end
end

local function solve(w)
    for _, objname in ipairs {"system","policy","interface","transform"} do
        for fullname, o in pairs(w._class[objname]) do
			if o.methodname then
				for _, name in ipairs(o.methodname) do
					if not o.method[name] then
						error(("`%s`'s `%s` method is not defined."):format(fullname, name))
					end
				end
			end
        end
    end
	require "component".solve(w._schema_data)
	require "policy".solve(w)
end

local function init(w, config)
	local schema_data = {}
	local schema = createschema(schema_data)
    decl_basetype(schema)
    local declaration = load_ecs(config.packname)

	local ecs = { world = w }
	w._class = { pipeline = {}, unique = {} }
	w._ecs = ecs
	w._decl = declaration
	w._schema_data = schema_data
	w._class.component = schema_data.map

	local function register(what)
		local class_set = {}
		ecs[what] = function(name)
			local package = getCurrentPackage()
			local fullname = package .. "|" .. name
			local r = class_set[fullname]
			if r == nil then
				log.info("Register", #what<8 and what.."  " or what, fullname)
				r = {}
				class_set[fullname] = r
				local decl = declaration[what][fullname]
				if not decl then
					--error(("%s `%s` in `%s` is not defined."):format(what, name, package))
					setmetatable(r, {
						__index = false,
						__newindex = function() end,
					})
				else
					if decl.method then
						decl.methodname = decl.method
						decl.method = {}
						decl.source = {}
						decl.defined = sourceinfo()
						setmetatable(r, {
							__index = false,
							__newindex = gen_method(decl),
						})
					else
						setmetatable(r, {
							__index = false,
							__newindex = function() error(("%s `%s` in `%s` has no method."):format(what, name, package)) end,
						})
					end
				end
			end
			return r
		end
	end
	register "system"
	register "transform"
	register "policy"
	register "interface"
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
	ecs.pipeline = function (name)
		local r = w._class.pipeline[name]
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
			w._class.pipeline[name] = r
		end
		return r
	end
	w._import = create_importor(w, ecs, declaration) 
	for _, k in ipairs(config.policy) do
		w._import.policy(k)
	end
	for _, k in ipairs(config.system) do
		w._import.system(k)
	end
    for _, file in ipairs(config.implement) do
        import_impl(file, ecs)
    end
	solve(w)
end

local function import(w, type, name)
	w._import[type](name)
	solve_object(w, type, name)
end

return {
	init = init,
	solve = solve,
	import = import,
}
