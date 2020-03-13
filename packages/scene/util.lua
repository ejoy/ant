local util = {}

local ecs = import_package "ant.ecs"
local keymap = import_package "ant.imguibase".keymap
local mouse_what = { 'LEFT', 'RIGHT', 'MIDDLE' }
local mouse_state = { 'DOWN', 'MOVE', 'UP' }

function util.start_new_world(config, world_class)
	local world = ecs.new_world(config, world_class)
	world:update_func "init" ()
	return world
end

function util.loop(world)
	local update = world:update_func "update"
	return function ()
		update()
		world:clear_removed()
	end
end

function util.create_world()
	local callback = {}
	local world
	local world_update
	local world_exit
	function callback.init(config, width, height)
		config.init_viewsize = {w=width, h=height}
		world = ecs.new_world(config)
		world:update_func "init" ()
		world_update = world:update_func "update"
		world_exit   = world:update_func "exit"
	end
	function callback.mouse_wheel(x, y, delta)
		world:pub {"mouse_wheel", delta, x, y}
	end
	function callback.mouse(x, y, what, state)
		world:pub {"mouse", mouse_what[what] or "UNKNOWN", mouse_state[state] or "UNKNOWN", x, y}
	end
	function callback.touch(x, y, id, state)
		world:pub {"touch", mouse_state[state] or "UNKNOWN", id, x, y }
	end
	function callback.keyboard(key, press, state)
		world:pub {"keyboard", keymap[key], press, {
			CTRL 	= (state & 0x01) ~= 0,
			ALT 	= (state & 0x02) ~= 0,
			SHIFT 	= (state & 0x04) ~= 0,
			SYS 	= (state & 0x08) ~= 0,
		}}
	end
	function callback.size(width,height,_)
		if world then
			world:pub {"resize", width, height}
		end
	end
	function callback.exit()
		if world_exit then
			world_exit()
		end
	end
	function callback.update()
		if world_update then
			world_update()
			world:clear_removed()
		end
	end
	return callback
end

return util
