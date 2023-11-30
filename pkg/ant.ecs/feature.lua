local interface = require "interface"
local fastio = require "fastio"
local vfs = require "vfs"
local pm = require "packagemanager"
local serialization = require "bee.serialization"

local function package_loadfile(packname, file, env)
	local path = "/pkg/"..packname.."/"..file
	local mem, symbol = vfs.read(path)
	if not mem then
		error(("file '%s' not found"):format(path))
	end
	local func, err = fastio.loadlua(mem, symbol, env)
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

local function emptyfunc(f)
    local info = debug.getinfo(f, "SL")
    if info.what ~= "C" then
        local lines = info.activelines
        return next(lines, next(lines)) == nil
    end
end

local function slove_component(w, name, info)
	local function register_component(decl)
		local ecs = w.w
		ecs:register(decl)
	end
	local component_class = w._components
	local type = info.type[1]
	local class = component_class[name] or {}
	if type == "lua" then
		register_component {
			name = name,
			type = "lua",
			init = class.init,
			marshal = class.marshal or serialization.packstring,
			demarshal = class.demarshal or nil,
			unmarshal = class.unmarshal or serialization.unpack,
		}
	elseif type == "c" then
		local t = {
			name = name,
			init = class.init,
			marshal = class.marshal,
			demarshal = class.demarshal,
			unmarshal = class.unmarshal,
		}
		for i, v in ipairs(info.field) do
			t[i] = v:match "^(.*)|.*$" or v
		end
		register_component(t)
	elseif type == "raw" then
		local t = {
			name = name,
			type = "raw",
			size = assert(math.tointeger(info.size[1])),
			init = class.init,
			marshal = class.marshal,
			demarshal = class.demarshal,
			unmarshal = class.unmarshal,
		}
		register_component(t)
	elseif type == nil then
		register_component {
			name = name
		}
	else
		register_component {
			name = name,
			type = type,
		}
	end

	local func = class.remove
	if func and not emptyfunc(func) then
		w._component_remove[name] = func
	end
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
		slove_component(w, name, v)
	end
	newdecl.system = {}
	newdecl.component = {}
end

return {
	import = import,
}
