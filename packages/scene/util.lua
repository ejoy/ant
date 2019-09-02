local util = {}; util.__index = util

local ecs 			= import_package "ant.ecs"
local mathadapter 	= import_package "ant.math.adapter"

local bullet_world 	= import_package "ant.bullet".bulletworld

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

function util.start_new_world(input_queue, fbw, fbh, packages, systems,other_args)
	if input_queue == nil then
		log.info("input queue is not privided, no input event will be received!")
	end

	local args =  { 
		mq = input_queue, 
		fb_size={w=fbw, h=fbh},
		Physics = bullet_world.new(),
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
	return new_world(packages, systems, {Physics = bullet_world.new(),})
end

function util.loop(world, arg)	
	local queue = {}
	local extra_queue = {
		update_marks = function () 	world:update_marks() end,
		clear_marks = function () 	world:clear_all_marks() end,
	}
	for _, updatetype in ipairs {
		"data_changed", 
		"asset_loaded",
		"before_update", 
		"update", 
		"after_update", 
		"update_marks",
		"clear_marks",
		"delete",
		"end_frame",
	} do
		local handlers = extra_queue[updatetype]
		if handlers == nil then
			handlers = world:update_func(updatetype, arg[updatetype])
		end

		queue[#queue+1] = handlers
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