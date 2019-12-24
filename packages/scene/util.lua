local util = {}; util.__index = util

local ecs 			= import_package "ant.ecs"
local mathadapter 	= import_package "ant.math.adapter"

local bullet        = require "bullet"

local function new_world(packages, systems, args)
	local world = ecs.new_world {
		packages = packages,
		systems = systems,
		args = args,
	}
	mathadapter.bind_math_adapter()	
	world:update_func "init" ()
	world:update_func "post_init" ()
    return world
end

local function create_physic()
	return {
		world = bullet.new(),
		objid_mapper = {},
	}
end

function util.start_new_world(input_queue, fbw, fbh, packages, systems,other_args)
	if input_queue == nil then
		log.info("input queue is not privided, no input event will be received!")
	end

	local args =  { 
		mq = input_queue, 
		fb_size={w=fbw, h=fbh},
		Physics = create_physic(),
	}
	if other_args then
		for k,v in pairs(other_args) do
			args[k] = v
		end
	end

	return new_world(packages, systems, args)
end

-- static_world use for editor module,only data needed
function util.start_static_world(packages,systems)
	return new_world(packages, systems, {
		Physics = create_physic()
	})
end

function util.loop(world, arg)	
	local queue = {}
	for _, updatetype in ipairs {
		"data_changed",
		"asset_loaded",
		"before_update",
		"update",
		"after_update",
		"delete",
		"end_frame",
	} do
		queue[#queue+1] = world:update_func(updatetype, arg[updatetype])
	end

	return function ()
		for _, q in ipairs(queue) do
			q()
		end

		world:clear_removed()
		if world.need_stop then
			world.stop()
		end
	end
end

return util