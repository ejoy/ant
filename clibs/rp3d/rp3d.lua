local lib = require "rp3d.core"
local math3d_adapter = require "math3d.adapter"

local world_mt = lib.collision_world_mt

do
	local shape = lib.shape
	local all_shapes = {}
	local function all_shapes_gc(self)
		for _, shape in ipairs(all_shapes) do
			lib.delete_shape(shape)
		end
	end
	setmetatable(all_shapes, { __gc = all_shapes_gc })

	-- todo : interning shapes
	function world_mt:new_shape(typename, ...)
		local s = shape[typename](...)
		all_shapes[#all_shapes+1] = s
		return s
	end
end

function lib.init(ms)
	lib.init = nil	-- call init only once

	world_mt.body_create = math3d_adapter.vector(ms, world_mt.body_create, 2)
	world_mt.set_transform = math3d_adapter.vector(ms, world_mt.set_transform, 3)
	world_mt.get_aabb = math3d_adapter.getter(ms, world_mt.get_aabb, "vv")
	world_mt.add_shape = math3d_adapter.vector(ms, world_mt.add_shape, 5)

	local rayfilter = math3d_adapter.vector(ms, lib.rayfilter, 1)
	local raycast = math3d_adapter.getter(ms, world_mt.raycast, "vv")

	function world_mt.raycast(world, p0, p1, maskbits)
		p0,p1 = rayfilter(p0,p1)
		local hit, pos, norm = raycast(world, p0, p1, maskbits or 0)
		if hit then
			return pos, norm
		end
	end
end

return lib
