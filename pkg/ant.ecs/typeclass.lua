local interface = require "interface"
local serialization = require "bee.serialization"
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

local function toint(v)
	local t = type(v)
	if t == "userdata" then
		local s = tostring(v)
		s = s:match "^%a+: (%x+)$" or s:match "^%a+: 0x(%x+)$"
		return tonumber(assert(s), 16)
	end
	if t == "number" then
		return v
	end
	assert(false)
end

local function cstruct(...)
	local ref = table.pack(...)
	local t = {}
	for i = 1, ref.n do
		t[i] = toint(ref[i])
	end
	local ecs_util = require "ecs.util"
	local data = string.pack("<"..("T"):rep(ref.n), table.unpack(t))
	return ecs_util.userdata(data, ref)
end

local function create_context(w, component_decl)
	local bgfx       = require "bgfx"
	local math3d     = require "math3d"
	local components = require "ecs.components"
	local ecs = w.w
	local function register_component(i, decl)
		local id, size = ecs:register(decl)
		assert(id == i)
		assert(size == components[decl.name] or 0)
	end
	for i, name in ipairs(components) do
		local decl = component_decl[name]
		if decl then
			component_decl[name] = nil
			register_component(i, decl)
		else
			local csize = components[name]
			if csize then
				register_component(i, {
					name = name,
					type = "raw",
					size = csize
				})
			else
				register_component(i, { name = name })
			end
		end
	end
	for _, decl in pairs(component_decl) do
		ecs:register(decl)
	end
	local ecs_context = ecs:context()
	w._ecs_world = cstruct(
		ecs_context,
		bgfx.CINTERFACE,
		math3d.CINTERFACE,
		bgfx.encoder_get(),
		0,0,0,0 --kMaxMember == 4
	)
end


local function slove_component(w, component_decl)
    local function register_component(decl)
        component_decl[decl.name] = decl
    end
    local component_class = w._components
    for name, info in pairs(w._decl.component) do
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

local function slove_system(w, system_class)
	local mark = {}
	local systems = w._systems
	for fullname, s in sortpairs(system_class) do
		for step_name, func in pairs(s) do
			local symbol = fullname .. "." .. step_name
			local info = emptyfunc(func)
			if info then
				log.warn(("`%s` is an empty method, it has been ignored. (%s:%d)"):format(symbol, info.source:sub(2), info.linedefined))
			else
				local step = systems[step_name]
				if step then
					step[#step+1] = {
						func = func,
						symbol = symbol,
					}
				else
					mark[step_name] = true
					systems[step_name] = {{
						func = func,
						symbol = symbol,
					}}
				end
			end
		end
	end

	for _, pl in pairs(w._decl.pipeline) do
		if pl.value then
			for _, v in ipairs(pl.value) do
				if v[1] == "stage" then
					local name = v[2]
					if mark[name] == nil then
						log.warn(("`%s` is an empty stage"):format(name))
					end
					mark[name] = nil
				end
			end
		end
	end

	for name in pairs(mark) do
		error(("pipeline is missing step `%s`, which is defined in system `%s`"):format(name, systems[name][1].symbol))
	end
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

local function package_require(w, packages, system_class, packname, file)
    local _PACKAGE = packages[packname]
	if not _PACKAGE then
		_PACKAGE = {
			_LOADED = {},
			ecs = create_ecs(w, packname, packages, system_class)
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

local function import_all(w, ecs, packages, system_class)
	local decl = w._decl
	local envs = {}
	for _, k in ipairs(ecs.feature) do
		interface.import_feature(envs, decl, package_loadfile, k)
	end
	for name, v in pairs(decl.system) do
		local impl = v.implement[1]
		if impl then
			log.debug("Import  system", name)
			if impl:sub(1,1) == ":" then
				system_class[name] = w:clibs(impl:sub(2))
			else
				package_require(w, packages, system_class, v.packname, impl)
			end
		end
	end
	for name, v in pairs(decl.component) do
		local impl = v.implement[1]
		if impl then
			log.debug("Import  component", name)
			package_require(w, packages, system_class, v.packname, impl)
		end
	end
end

function create_ecs(w, packname, packages, system_class)
    local ecs = { world = w }
    function ecs.system(name)
        local fullname = packname .. "|" .. name
        local r = system_class[fullname]
        if r == nil then
			if not w._initializing then
				error(("system `%s` can only be imported during initialization."):format(name))
			end
            log.debug("Register system   ", fullname)
            r = {}
            system_class[fullname] = r
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
        return package_require(w, packages, system_class, pkg, file)
    end
    return ecs
end

local function init(w, config)
	log.info "world initializing"
	local packages = {}
	local system_class = {}
    local component_decl = {}
	w._initializing = true
	w._components = {}
	w._systems = {}
	w._decl = {
		pipeline = {},
		component = {},
		feature = {},
		system = {},
		policy = {},
	}
	import_all(w, config.ecs, packages, system_class)
	slove_component(w, component_decl)
	slove_system(w, system_class)
	create_context(w, component_decl)
	w._initializing = nil
	log.info "world initialized"
end

return {
	init = init,
}
