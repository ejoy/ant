local util = {}; util.__index = util

local ms = import_package "ant.math" .stack
local log = log and log.info(...) or print
local ecs = import_package "ant.ecs"
local mathadapter = import_package "ant.math.adapter"

local handlers = {	
	parent = function (comp, value)
		comp.parent = value
	end,
	s = function (comp, value)
		ms(comp.s, value, "=")
	end,
	r = function (comp, value)
		ms(comp.r, value, "=")
	end,
	t = function (comp, value)
		ms(comp.t, value, "=")
	end,
	base = function (comp, value)
		ms(comp.base, value, "=")
	end,
}

function util.handle_transform(events, comp)
	for event, value in pairs(events) do
		local handler = handlers[event]
		if handler then
			handler(comp, value)
		else
			print('handler is not default in transform:', event)
		end
	end
end

local bullet_world = import_package "ant.bullet".bulletworld

function util.start_new_world(input_queue, fbw, fbh, packages, systems,other_args)
	if input_queue == nil then
		log("input queue is not privided, no input event will be received!")
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

	local world = ecs.new_world {
		packages = packages,
		systems = systems,		
		args = args,
	}
	
	mathadapter.bind_math_adapter()	
	world:update_func("init")()
    return world
end

-- static_world use for editor module,only data needed
function util.start_static_world(packages,systems)
	local world = ecs.new_world {
		packages = packages,
		systems = systems,
		args = {
			Physics = bullet_world.new(),
		},
	}
	mathadapter.bind_math_adapter()	
	world:update_func("init")()
    return world
end

function util.loop(world, arg)	
	local queue = {}
	for _, updatetype in ipairs {
		"post_init", 
		"event_changed", 
		"before_update", 
		"update", 
		"after_update", 
		"delete",
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