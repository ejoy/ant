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

local function slove_component(w)
	local ecs = w.w
	local function register_component(decl)
		ecs:register(decl)
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

local function create_context(w)
	local bgfx = require "bgfx"
	local math3d = require "math3d"
	local ecs = w.w
	w._ecs_world = cstruct(
		ecs:context(),
		bgfx.CINTERFACE,
		math3d.CINTERFACE,
		bgfx.encoder_get(),
		0,0,0,0 --kMaxMember == 4
	)
end

local function init(w)
	slove_component(w)
	create_context(w)
end

return {
	init = init,
}
