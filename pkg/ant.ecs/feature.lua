local interface = require "interface"
local fastio = require "fastio"
local vfs = require "vfs"
local pm = require "packagemanager"

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

local function emptyfunc(f)
	local info = debug.getinfo(f, "SL")
	if info.what ~= "C" then
		local lines = info.activelines
		if next(lines, next(lines)) == nil then
			return info
		end
	end
end

local function slove_system(w, systems)
	local system_step = {}
	for fullname, s in sortpairs(systems) do
		for step_name, func in pairs(s) do
			local symbol = fullname .. "." .. step_name
			local info = emptyfunc(func)
			if info then
				log.warn(("`%s` is an empty method, it has been ignored. (%s:%d)"):format(symbol, info.source:sub(2), info.linedefined))
			else
				local v = { func = func, symbol = symbol }
				local step = system_step[step_name]
				if step then
					step[#step+1] = v
				else
					system_step[step_name] = {v}
				end
			end
		end
	end
	return system_step
end

local function package_loadfile(packname, file, env)
	local path = "/pkg/"..packname.."/"..file
	local realpath = vfs.realpath(path)
	if not realpath then
		error(("file '%s' not found"):format(path))
	end
	local func, err = fastio.loadfile(realpath, path, env)
	if not func then
		error(("error loading file '%s':\n\t%s"):format(path, err))
	end
	return func
end

local create_ecs

local function package_require(w, packname, file)
	local packages = w._packages
	local _PACKAGE = packages[packname]
	if not _PACKAGE then
		_PACKAGE = {
			_LOADED = {},
			ecs = create_ecs(w, packname)
		}
		packages[packname] = _PACKAGE
	end
	local p = _PACKAGE._LOADED[file]
	if p ~= nil then
		return p
	end
	local env = pm.loadenv(packname)
	local initfunc = package_loadfile(packname, file, env)
	local r = initfunc(_PACKAGE.ecs)
	if r == nil then
		r = true
	end
	_PACKAGE._LOADED[file] = r
	return r
end

function create_ecs(w, packname)
	local ecs = { world = w }
	function ecs.system(name)
		local fullname = packname .. "|" .. name
		local r = w._systems[fullname]
		if r == nil then
			log.debug("Register system   ", fullname)
			r = {}
			w._systems[fullname] = r
			w._initsystems[fullname] = r
			w._system_changed = true
		end
		return r
	end
	function ecs.component(fullname)
		local r = w._components[fullname]
		if r == nil then
			if not w._decl.component[fullname] then
				error(("component `%s` has no declaration."):format(fullname))
			end
			log.debug("Register component", fullname)
			r = {}
			w._components[fullname] = r
		end
		return r
	end
	function ecs.require(fullname)
		local pkg, name = fullname:match "^([^|]*)|(.*)$"
		if not pkg then
			pkg = packname
			name = fullname
		end
		local file = name:gsub('%.', '/')..".lua"
		return package_require(w, pkg, file)
	end
	return ecs
end

local function import(w, features)
	local newdecl = w._newdecl
	for _, k in ipairs(features) do
		interface.import_feature(w._envs, w._decl, newdecl, package_loadfile, k)
	end
	for name, v in pairs(newdecl.system) do
		local impl = v.implement[1]
		if impl then
			log.debug("Import  system", name)
			if impl:sub(1,1) == ":" then
				local s = w:clibs(impl:sub(2))
				w._systems[name] = s
				w._initsystems[name] = s
				w._system_changed = true
			else
				package_require(w, v.packname, impl)
			end
		end
	end
	for name, v in pairs(newdecl.component) do
		local impl = v.implement[1]
		if impl then
			log.debug("Import  component", name)
			package_require(w, v.packname, impl)
		end
	end
	newdecl.system = {}
	newdecl.component = {}
end

return {
	import = import,
	slove_system = slove_system,
}
