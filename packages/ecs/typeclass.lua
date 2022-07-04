local interface = require "interface"
local pm = require "packagemanager"
local create_ecs = require "ecs"

local function splitname(fullname)
    return fullname:match "^([^|]*)|(.*)$"
end

local OBJECT = {"system","policy","interface","component"}

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
	require_policy = "policy",
	require_transform = "transform",
	component = "component",
	component_opt = "component",
}

local copy = {}
function copy.policy(v)
	return {
		policy = v.require_policy,
		component = v.component,
		component_opt = v.component_opt,
	}
end
function copy.component(v)
	return {}
end
function copy.system() return {} end
function copy.interface() return {} end

local function create_importor(w)
	local declaration = w._decl
	local import = {}
    for _, objname in ipairs(OBJECT) do
		local class = {}
		w._class[objname] = class
		import[objname] = function (package, name)
			local v = class[name]
            if v then
                return v
			end
			if not w._initializing and objname == "system" then
                error(("system `%s` can only be imported during initialization."):format(name))
			end
            local v = declaration[objname][name]
			if not v then
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
			end
			if objname == "policy" then
				solve_policy(name, res)
			end
			if v.implement and v.implement[1] then
				local impl = v.implement[1]
				if impl:sub(1,1) == ":" then
					v.c = true
					w._class.system[name] = require(impl:sub(2))
				else
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

local function toint(v)
	local t = type(v)
	if t == "userdata" then
		local s = tostring(v):match "%a+: (%x+)"
		return tonumber(s, 16)
	end
	assert(false)
end

local function cstruct(...)
	local ref = table.pack(...)
	local t = {}
	for i = 1, ref.n do
		t[i] = toint(ref[i])
	end
	return string.pack("<"..("T"):rep(ref.n), table.unpack(t))
		, ref
end

local function create_context(w)
	local bgfx = require "bgfx"
	local math3d = require "math3d"
	local ecs_context = w.w:context {
		"scene_update",
		"scene",
		"id",
		"scene_changed",
	}
	w._ecs_world,
	w._ecs_ref = cstruct(
		ecs_context,
		bgfx.CINTERFACE,
		math3d.CINTERFACE,
		bgfx.encoder_get()
	)
end

local function init(w, config)
	w._initializing = true
	w._class = {}
	w._decl = interface.new(function(current, packname, filename)
		local file = "/pkg/"..packname.."/"..filename
		log.debug(("Import decl %q"):format(file))
		return assert(pm.findenv(current, packname).loadfile(file))
	end)
	w._importor = create_importor(w)
	function w:_import(objname, package, name)
		local res = w._class[objname][name]
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
	local import = w._importor
	for _, objname in ipairs(OBJECT) do
		if config.ecs[objname] then
			for _, k in ipairs(config.ecs[objname]) do
				import[objname](nil, k)
			end
		end
	end
	if config.update_decl then
		config.update_decl(w)
	end
	w._initializing = false

    for _, objname in ipairs(OBJECT) do
		for fullname, o in pairs(w._class[objname]) do
			solve_object(o, w, objname, fullname)
        end
    end
	create_context(w)
	require "system".solve(w)
end

return {
	init = init,
}
