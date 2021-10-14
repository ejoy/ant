local interface = require "interface"
local pm = require "packagemanager"
local create_ecs = require "ecs"

local function splitname(fullname)
    return fullname:match "^([^|]*)|(.*)$"
end

local OBJECT = {"system","policy_v2","interface","component_v2","pipeline"}

local function solve_object(o, w, what, fullname)
	local decl = w._decl[what][fullname]
	if decl and decl.method then
		for _, name in ipairs(decl.method) do
			if not o[name] then
				error(("`%s`'s `%s` method is not defined."):format(fullname, name))
			end
		end
	end
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
	require_policy_v2 = "policy_v2",
	require_transform = "transform",
	component_v2 = "component_v2",
	component_opt = "component_v2",
	pipeline = "pipeline",
}

local function table_append(t, a)
	table.move(a, 1, #a, #t+1, t)
end

local copy = {}
function copy.policy_v2(v)
	return {
		policy_v2 = v.require_policy_v2,
		component_v2 = v.component_v2,
		component_opt = v.component_opt,
	}
end
function copy.pipeline(v)
	return {
		value = v.value
	}
end
function copy.component_v2(v)
	return {
		type = v.type[1]
	}
end
function copy.system() return {} end
function copy.interface() return {} end
function copy.component() return {} end
function copy.action() return {} end

local function create_importor(w)
	local declaration = w._decl
	local import = {}
    for _, objname in ipairs(OBJECT) do
		w._class[objname] = setmetatable({}, {__index=function(_, name)
			--TODO
			local res = import[objname](nil, name)
			if res then
				solve_object(res, w, objname, name)
			end
			return res
		end})
		import[objname] = function (package, name)
			local class = w._class[objname]
			local v = rawget(class, name)
            if v then
                return v
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
			log.debug("Import  ", objname, name)
			local res = copy[objname](v)
			class[name] = res
			for _, tuple in ipairs(v.value) do
				local what, k = tuple[1], tuple[2]
				local attrib = check_map[what]
				if attrib then
					import[attrib](package, k)
				end
				if what == "unique_component" then
					w._class.unique[k] = true
				end
			end
			if objname == "policy" then
				solve_policy(name, res)
			end
			if v.implement then
				for _, impl in ipairs(v.implement) do
					local pkg = v.packname
					local file = impl:gsub("^(.*)%.lua$", "%1")
					pm.findenv(package, pkg)
						.include_ecs(w._ecs[pkg], file)
				end
			end
			return res
		end
	end
	return import
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
	w._initializing = true
	w._class = { unique = {} }
	w._decl = interface.new(function(current, packname, filename)
		local file = "/pkg/"..packname.."/"..filename
		log.debug(("Import decl %q"):format(file))
		return assert(pm.findenv(current, packname).loadfile(file))
	end)
	w._importor = create_importor(w)
	function w:_import(objname, package, name)
		local res = rawget(w._class[objname], name)
		if res then
			return res
		end
		res = w._importor[objname](package, name)
		if res then
			solve_object(res, w, objname, name)
		end
		return res
	end
	w._set_methods = setmetatable({}, {
		__index = w._methods,
		__newindex = function(_, name, f)
			if w._methods[name] then
				local info = debug.getinfo(w._methods[name], "Sl")
				assert(info.source:sub(1,1) == "@")
				error(string.format("Method `%s` has already defined at %s(%d).", name, info.source:sub(2), info.linedefined))
			end
			w._methods[name] = f
		end,
	})
	setmetatable(w._ecs, {__index = function (_, package)
		return create_ecs(w, package)
	end})

	config.ecs = config.ecs or {}
	if config.ecs.import then
		for _, k in ipairs(config.ecs.import) do
			import_decl(w, k)
		end
	end
	if config.update_decl then
		config.update_decl(w)
	end

	local import = w._importor
	for _, objname in ipairs(OBJECT) do
		if config.ecs[objname] then
			for _, k in ipairs(config.ecs[objname]) do
				import[objname](nil, k)
			end
		end
	end
    --for _, objname in ipairs(OBJECT) do
	--	setmetatable(w._class[objname], nil)
	--end
	w._initializing = false

    for _, objname in ipairs(OBJECT) do
		for fullname, o in pairs(w._class[objname]) do
			solve_object(o, w, objname, fullname)
        end
    end
	require "system".solve(w)
end

return {
	init = init,
}
