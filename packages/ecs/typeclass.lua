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
	log.info(("Import impl %q"):format(path:string()))
	pushCurrentPackage(packname)
	module(ecs)
	popCurrentPackage()
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
	local callback = keys(c.method)
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
		rawset(c.methodfunc, key, func)
	end
end

local function decl_basetype(w, schema, schema_data)
	schema:primtype("tag", true)
	schema:primtype("entityid", -1)
	schema:primtype("int", 0)
	schema:primtype("real", 0.0)
	schema:primtype("string", "")
	schema:primtype("boolean", false)
	w._class.component = {}
	w._class.component["tag"] = schema_data.map["tag"]
	w._class.component["entityid"] = schema_data.map["entityid"]
	w._class.component["int"] = schema_data.map["int"]
	w._class.component["real"] = schema_data.map["real"]
	w._class.component["string"] = schema_data.map["string"]
	w._class.component["boolean"] = schema_data.map["boolean"]
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
	pipeline = "pipeline",
	stage = nil,
}

local OBJECT = {"system","policy","transform","interface","component","pipeline"}

local function create_importor(w, ecs, schema_data, declaration)
    local import = {}
    for _, objname in ipairs(OBJECT) do
		w._class[objname] = w._class[objname] or {}
		import[objname] = function (name)
			local res = w._class[objname]
            if res[name] then
                return
			end
			if not w._initializing and objname == "system" then
                error(("system `%s` can only be imported during initialization."):format(name))
			end
            local v = declaration[objname][name]
			if not v then
				if objname == "pipeline" then
					return
				end
                error(("invalid %s name: `%s`."):format(objname, name))
            end
            log.info("Import  ", objname, name)
			if objname == "component" then
				res[name] = true
			else
				res[name] = v
			end
			for _, tuple in ipairs(v.value) do
				local what, k = tuple[1], tuple[2]
				local attrib = check_map[what]
				if attrib then
					import[attrib](k)
					if what == "unique_component" then
						w._class.unique[k] = true
					end
				end
			end
			if v.implement then
				for _, impl in ipairs(v.implement) do
					import_impl("/pkg/"..v.packname.."/"..impl, ecs)
				end
			end
			if objname == "component" then
				res[name] = schema_data.map[name]
			end
		end
	end
	return import
end

local function solve_object(o, fullname)
	if o and o.method then
		for _, name in ipairs(o.method) do
			if not o.methodfunc[name] then
				error(("`%s`'s `%s` method is not defined."):format(fullname, name))
			end
		end
	end
end

local function import_decl(w, fullname)
	local packname, filename
	assert(fullname:sub(1,1) == "@")
	if fullname:find "/" then
		packname, filename = fullname:match "^@([^/]*)/(.*)$"
	else
		packname = fullname:sub(2)
		filename = "package.ecs"
	end
	w._decl:load(packname, filename)
	w._decl:check()
end

local function init(w, config)
	local schema_data = {}
	local schema = createschema(schema_data)

	local ecs = { world = w }
	local declaration = interface.new(function(packname, filename)
		local file = fs.path "/pkg" / packname / filename
		log.info(("Import decl %q"):format(file:string()))
        return assert(fs.loadfile(file))
	end)

	w._decl = declaration
	w._schema_data = schema_data
	w._class = { unique = {} }
	w._initializing = true

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
						decl.methodfunc = {}
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
		return schema:type(name)
	end
	ecs.component_alias = function (name, ...)
		return schema:typedef(name, ...)
	end
	ecs.tag = function (name)
		ecs.component_alias(name, "tag")
	end

	decl_basetype(w, schema, schema_data)

	for _, k in ipairs(config.ecs.import) do
		import_decl(w, k)
	end
	w._import = create_importor(w, ecs, schema_data, declaration)
	
	for _, objname in ipairs(OBJECT) do
		if config.ecs[objname] then
			for _, k in ipairs(config.ecs[objname]) do
				w._import[objname](k)
			end
		end
	end
	w._initializing = false

    for _, objname in ipairs(OBJECT) do
		for fullname, o in pairs(w._class[objname]) do
			solve_object(o, fullname)
        end
    end
	require "component".solve(w) -- TODO
	require "policy".solve(w)    -- TODO
	require "system".solve(w)
end

local function import_object(w, type, fullname)
	w._import[type](fullname)
	solve_object(w._class[type][fullname], fullname)
end

return {
	init = init,
	import_decl = import_decl,
	import_object = import_object,
}
