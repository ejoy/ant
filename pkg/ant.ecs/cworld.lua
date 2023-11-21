local serialization = require "bee.serialization"

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

local function init(w)
	local component_decl = {}
	slove_component(w, component_decl)
	create_context(w, component_decl)
end

return {
    init = init,
}
