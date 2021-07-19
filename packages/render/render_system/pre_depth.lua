local ecs = ...
local world = ecs.world

local bgfx = require "bgfx"

local irq = world:interface "ant.render|irenderqueue"
local irender = world:interface "ant.render|irender"

local imaterial		= world:interface "ant.asset|imaterial"
local ipf			= world:interface "ant.scene|iprimitive_filter"

local function can_write_depth(state)
	local s = bgfx.parse_state(state)
	local wm = s.WRITE_MASK
	return wm == nil or wm:match "Z"
end

local s = ecs.system "pre_depth_primitive_system"

local evadd = world:sub {"primitive_filter", "depth", "add"}
local evdel = world:sub {"primitive_filter", "depth", "del"}

local function which_material(eid)
	local pef = world:singleton_entity "pre_depth_queue"
	return world[eid].skinning_type == "GPU" and pef.pre_depth_skinning_material or pef.pre_depth_material
end

function s.update_filter()
	for _, _, _, eid, filter in evadd:unpack() do
		local e = world[eid]
		local rc = e._rendercache
		local fx = rc.fx
		local fxtype = fx.setting.surfacetype
		if fxtype == "opaticy" then
			local items = filter.result[fxtype].items
			local material = assert(which_material(eid))
			if can_write_depth(rc.state) then
				ipf.add_item(items, eid, setmetatable({
					eid			= eid,
					properties	= material.properties,
					fx			= material.fx,
					state		= irender.check_primitive_mode_state(rc.state, material.state),
				}, {__index=rc}))
			end
		end
	end
	for _, _, _, eid, filter in evdel:unpack() do
		local e = world[eid]
		local rc = e._rendercache
		local fx = rc.fx
		local fxtype = fx.setting.surfacetype
		if fxtype == "opaticy" then
			local items = filter.result[fxtype].items
			ipf.remove_item(items, eid)
		end
	end
end
