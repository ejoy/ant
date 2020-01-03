local util = {}; util.__index = util

local ecs 			= import_package "ant.ecs"
local mathadapter 	= import_package "ant.math.adapter"

local bullet        = require "bullet"

local function new_world(config)
	local world = ecs.new_world(config)
	mathadapter.bind_math_adapter()
	world:update_func "init" ()
    return world
end

local function create_physic()
	return {
		world = bullet.new(),
		objid_mapper = {},
	}
end

function util.start_new_world(fbw, fbh, config)
	config.fb_size={w=fbw, h=fbh}
	config.Physics = create_physic()
	return new_world(config)
end

-- static_world use for editor module,only data needed
function util.start_static_world(packages,systems)
	return new_world(packages, systems, {
		Physics = create_physic()
	})
end

function util.loop(world)
	local update = world:update_func "update"
	return function ()
		update()
		world:clear_removed()
		if world.need_stop then
			world.stop()
		end
	end
end

return util
