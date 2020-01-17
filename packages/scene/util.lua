local util = {}

local ecs         = import_package "ant.ecs"
local mathadapter = import_package "ant.math.adapter"

function util.start_new_world(fbw, fbh, config)
	config.fb_size = {w=fbw, h=fbh}
	local world = ecs.new_world(config)
	mathadapter.bind_math_adapter()
	world:update_func "init" ()
	return world
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
