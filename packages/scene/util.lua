local util = {}

local ecs = import_package "ant.ecs"

function util.create_world()
	local callback = {}
	local world
	local world_update
	local world_exit
	function callback.init(config)
		world = ecs.new_world(config, config.world_class)
		world:update_func "init" ()
		world_update = world:update_func "update"
		world_exit   = world:update_func "exit"
	end
	function callback.mouse_wheel(x, y, delta)
		world:pub {"mouse_wheel", delta, x, y}
	end
	function callback.mouse(x, y, what, state)
		world:pub {"mouse", what, state, x, y}
	end
	function callback.touch(x, y, id, state)
		world:pub {"touch", state, id, x, y }
	end
	function callback.keyboard(key, press, state)
		world:pub {"keyboard", key, press, state}
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
	function callback.get_world()
		return world
	end
	return callback
end

return util
