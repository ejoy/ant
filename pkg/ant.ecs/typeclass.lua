local interface = require "interface"
local serialization = require "bee.serialization"
local system = require "system"

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

local function create_context(w)
	local bgfx       = require "bgfx"
	local math3d     = require "math3d"
	local components = require "ecs.components"
	local ecs = w.w
	local component_decl = w._component_decl
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
	w._component_decl = nil
	local ecs_context = ecs:context()
	w._ecs_world = cstruct(
		ecs_context,
		bgfx.CINTERFACE,
		math3d.CINTERFACE,
		bgfx.encoder_get(),
		0,0,0,0 --kMaxMember == 4
	)
end


local function slove_component(w)
    w._component_decl = {}
    local function register_component(decl)
        w._component_decl[decl.name] = decl
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

local function import_all(w, system_class, ecs)
	local envs = {}
	for _, k in ipairs(ecs.feature) do
		interface.import_feature(envs, w._decl, k)
	end
	for name, v in pairs(w._decl.system) do
		local impl = v.implement[1]
		if impl then
			log.debug("Import  system", name)
			if impl:sub(1,1) == ":" then
				system_class[name] = w:clibs(impl:sub(2))
			else
				w:_package_require(v.packname, impl)
			end
		end
	end
	for name, v in pairs(w._decl.component) do
		local impl = v.implement[1]
		if impl then
			log.debug("Import  component", name)
			w:_package_require(v.packname, impl)
		end
	end
end

local function create_ecs(w, package, system_class)
    local ecs = { world = w }
    function ecs.system(name)
        local fullname = package .. "|" .. name
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
            pkg = package
            name = fullname
        end
        local file = name:gsub('%.', '/')..".lua"
        return w:_package_require(pkg, file)
    end
    return ecs
end

local function init(w, config)
	log.info "world initializing"
	local system_class = {}
	w._initializing = true
	w._components = {}
	w._decl = {
		pipeline = {},
		component = {},
		feature = {},
		system = {},
		policy = {},
	}
	setmetatable(w._packages, {__index = function (self, package)
		local v = {
			_LOADED = {},
			ecs = create_ecs(w, package, system_class)
		}
		self[package] = v
		return v
	end})
	import_all(w, system_class, config.ecs)
	slove_component(w)
	create_context(w)
	system.solve(w, system_class)
	w._initializing = nil
	log.info "world initialized"
end

return {
	init = init,
}
