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

local function splitname(fullname)
    return fullname:match "^([^|]*)|(.*)$"
end

local function solve_policy(fullname, v)
	local _, policy_name = splitname(fullname)
	local union_name, name = policy_name:match "^([%a_][%w_]*)%.([%a_][%w_]*)$"
	if not union_name then
		name = policy_name:match "^([%a_][%w_]*)$"
	end
	if not name then
		error(("invalid policy name: `%s`."):format(policy_name))
	end
	v.union = union_name
end

local check_map = {
	require_system = "system",
	require_interface = "interface",
	require_policy = "policy",
	require_transform = "transform",
	pipeline = "pipeline",
	connection = "connection",
}

local OBJECT = {"system","policy","transform","interface","component","pipeline","connection"}

local function create_importor(w, ecs, declaration)
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
				if objname == "component" then
					return
				end
                error(("invalid %s name: `%s`."):format(objname, name))
            end
            log.info("Import  ", objname, name)
			res[name] = v
			for _, tuple in ipairs(v.value) do
				local what, k = tuple[1], tuple[2]
				local attrib = check_map[what]
				if attrib then
					import[attrib](k)
				end
				if what == "unique_component" then
					w._class.unique[k] = true
				end
			end
			if objname == "policy" then
				solve_policy(name, v)
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
	w._class = { component = {}, unique = {} }
	local schema = createschema(w._class.component)

	local ecs = { world = w }
	local declaration = interface.new(function(packname, filename)
		local file = fs.path "/pkg" / packname / filename
		log.info(("Import decl %q"):format(file:string()))
        return assert(fs.loadfile(file))
	end)

	w._decl = declaration
	w._initializing = true

	local function register(what)
		local class_set = {}
		ecs[what] = function(name)
			local package = getCurrentPackage()
			local fullname = what == "connection" and name or package .. "|" .. name
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
	register "interface"
	register "connection"
	ecs.component = schema
	ecs.component_alias = schema
	ecs.tag = schema

	for _, k in ipairs(config.ecs.import) do
		import_decl(w, k)
	end
	w._import = create_importor(w, ecs, declaration)
	
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
