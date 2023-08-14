local interface = require "interface"
local pm = require "packagemanager"
local serialization = require "bee.serialization"
local create_ecs = require "ecs"

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

local check_map = {
	require_system = "system",
	require_policy = "policy",
	require_transform = "transform",
	component = "component",
	component_opt = "component",
}

local function create_importor(w)
	local import = {}
	local system_class = {}
	local system_decl = w._decl.system
	local component_class = {}
	local component_decl = w._decl.component
	local policy_class = {}
	local policy_decl = w._decl.policy
	w._class.system = system_class
	w._class.component = component_class
	w._class.policy = policy_class
	import.system = function (name)
		local v = system_class[name]
		if v then
			return v
		end
		if not w._initializing then
			error(("system `%s` can only be imported during initialization."):format(name))
		end
		v = system_decl[name]
		if not v then
			error(("invalid system name: `%s`."):format(name))
		end
		log.debug("Import  system", name)
		local res = {}
		system_class[name] = res
		for _, tuple in ipairs(v.value) do
			local what, k = tuple[1], tuple[2]
			local attrib = check_map[what]
			if attrib then
				import[attrib](k)
			end
		end
		if v.implement and v.implement[1] then
			local impl = v.implement[1]
			if impl:sub(1,1) == ":" then
				v.c = true
				w._class.system[name] = w:clibs(impl:sub(2))
			else
				local pkg = v.packname
				local file = impl:gsub("^(.*)%.lua$", "%1"):gsub("/", ".")
				w._ecs[pkg].include_ecs(file)
			end
		end
		return res
	end
	import.component = function (name)
		local v = component_class[name]
		if v then
			return v
		end
		v = component_decl[name]
		if not v then
			error(("invalid component name: `%s`."):format(name))
		end
		log.debug("Import  component", name)
		local res = {}
		component_class[name] = res
		for _, tuple in ipairs(v.value) do
			local what, k = tuple[1], tuple[2]
			local attrib = check_map[what]
			if attrib then
				import[attrib](k)
			end
		end
		if v.implement and v.implement[1] then
			local impl = v.implement[1]
			local pkg = v.packname
			local file = impl:gsub("^(.*)%.lua$", "%1"):gsub("/", ".")
			w._ecs[pkg].include_ecs(file)
		end
		return res
	end
	import.policy = function (name)
		local v = policy_class[name]
		if v then
			return v
		end
		v = policy_decl[name]
		if not v then
			error(("invalid policy name: `%s`."):format(name))
		end
		log.debug("Import  policy", name)
		local res = {
			policy = v.require_policy,
			component = v.component,
			component_opt = v.component_opt,
		}
		policy_class[name] = res
		for _, tuple in ipairs(v.value) do
			local what, k = tuple[1], tuple[2]
			local attrib = check_map[what]
			if attrib then
				import[attrib](k)
			end
		end
		return res
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
	return string.pack("<"..("T"):rep(ref.n), table.unpack(t))
		, ref
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
	w._ecs_world,
	w._ecs_ref = cstruct(
		ecs_context,
		bgfx.CINTERFACE,
		math3d.CINTERFACE,
		bgfx.encoder_get(),
		0,0,0,0 --kMaxMember == 4
	)
end

local function slove_system(w)
	for fullname, o in pairs(w._class.system) do
		local decl = w._decl.system[fullname]
		if decl and decl.method then
			for _, name in ipairs(decl.method) do
				if not o[name] then
					error(("`%s`'s `%s` method is not defined."):format(fullname, name))
				end
			end
		end
	end
end

local function slove_component(w)
	for fullname, o in pairs(w._class.component) do
		local decl = w._decl.component[fullname]
		if decl and decl.method then
			for _, name in ipairs(decl.method) do
				if not o[name] then
					error(("`%s`'s `%s` method is not defined."):format(fullname, name))
				end
			end
		end
	end
    w._component_decl = {}
    local function register_component(decl)
        w._component_decl[decl.name] = decl
    end
    local component_class = w._class.component
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

local function init(w, config)
	w._initializing = true
	w._class = {}
	w._decl = interface.new(function(_, packname, filename)
		local file = "/pkg/"..packname.."/"..filename
		log.debug(("Import decl %q"):format(file))
		return assert(pm.loadenv(packname).loadfile(file))
	end)
	local import = create_importor(w)
	w._importor = import
	setmetatable(w._ecs, {__index = function (_, package)
		return create_ecs(w, package)
	end})
	config.ecs = config.ecs or {}
	if config.ecs.import then
		for _, k in ipairs(config.ecs.import) do
			import_decl(w, k)
		end
	end
	if config.ecs.system then
		for _, k in ipairs(config.ecs.system) do
			import.system(k)
		end
	end
	if config.ecs.policy then
		for _, k in ipairs(config.ecs.policy) do
			import.policy(k)
		end
	end
	if config.ecs.component then
		for _, k in ipairs(config.ecs.component) do
			import.component(k)
		end
	end

	slove_system(w)
	slove_component(w)
	create_context(w)
	w._initializing = false
end

return {
	init = init,
}
