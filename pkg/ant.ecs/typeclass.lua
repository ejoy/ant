local interface = require "interface"
local pm = require "packagemanager"
local serialization = require "bee.serialization"

local function splitname(fullname)
    return fullname:match "^([^|]*)|(.*)$"
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

local function import_all(w, ecs)
	local function import_feature(name)
		local packname, _ = splitname(name)
		if not packname then
			w._decl:load(name, "package.ecs", import_feature)
			return
		else
			w._decl:load(packname, "package.ecs", import_feature)
		end
		local v = w._decl.feature[name]
		if not v then
			error(("invalid feature name: `%s`."):format(name))
		end
		if v.imported then
			return
		end
		v.imported = true
		if v.import then
			log.debug("Import  feature", name)
			for _, fullname in ipairs(v.import) do
				local packname, filename
				if fullname:sub(1,1) == "@" then
					if fullname:find "/" then
						packname, filename = fullname:match "^@([^/]*)/(.*)$"
					else
						packname = fullname:sub(2)
						filename = "package.ecs"
					end
				else
					packname = v.packname
					filename = fullname
				end
				w._decl:load(packname, filename, import_feature)
			end
		end
	end
	for _, k in ipairs(ecs.feature) do
		import_feature(k)
	end
	w._decl:check()
	for name, v in pairs(w._decl.system) do
		if v.implement and v.implement[1] and not v.imported then
			log.debug("Import  system", name)
			local impl = v.implement[1]
			if impl:sub(1,1) == ":" then
				v.c = true
				w._class.system[name] = w:clibs(impl:sub(2))
			else
				local pkg = v.packname
				local file = impl:gsub("^(.*)%.lua$", "%1"):gsub("/", ".")
				w:_package_require(pkg, file)
			end
		end
	end
	for name, v in pairs(w._decl.component) do
		if v.implement[1] and not v.imported then
			v.imported = true
			log.debug("Import  component", name)
			local impl = v.implement[1]
			local pkg = v.packname
			local file = impl:gsub("^(.*)%.lua$", "%1"):gsub("/", ".")
			w:_package_require(pkg, file)
		end
	end
end

local function create_ecs(w, package, tasks)
    local ecs = { world = w }
    function ecs.system(name)
        local fullname = package .. "|" .. name
        local r = w._class.system[fullname]
        if r == nil then
			if not w._initializing then
				error(("system `%s` can only be imported during initialization."):format(name))
			end
            log.debug("Register system   ", fullname)
            r = {}
            w._class.system[fullname] = r
            table.insert(tasks.system, fullname)
        end
        return r
    end
    function ecs.component(fullname)
        local r = w._class.component[fullname]
        if r == nil then
            if not w._decl.component[fullname] then
                error(("component `%s` has no declaration."):format(fullname))
            end
            log.debug("Register component", fullname)
            r = {}
            w._class.component[fullname] = r
        end
        return r
    end
    function ecs.require(fullname)
        local pkg, file = fullname:match "^([^|]*)|(.*)$"
        if not pkg then
            pkg = package
            file = fullname
        end
        return w:_package_require(pkg, file)
    end
    return ecs
end

local function init(w, config)
	w._initializing = true
	w._class = {
		system = {},
		component = {},
	}
	w._decl = interface.new(function(_, packname, filename)
		local file = "/pkg/"..packname.."/"..filename
		log.debug(("Import decl %q"):format(file))
		return assert(pm.loadenv(packname).loadfile(file))
	end)
	local tasks = config.ecs
	tasks.system = tasks.system or {}
	setmetatable(w._packages, {__index = function (self, package)
		local v = {
			_LOADED = {},
			ecs = create_ecs(w, package, tasks)
		}
		self[package] = v
		return v
	end})
	import_all(w, tasks)
	slove_component(w)
	create_context(w)
	w._initializing = nil
end

return {
	init = init,
}
