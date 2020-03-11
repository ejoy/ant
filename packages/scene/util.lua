local util = {}; util.__index = util

local ecs 			= import_package "ant.ecs"

function util.start_new_world(config, world_class)
	local world = ecs.new_world(config, world_class)
	world:update_func "init" ()
	return world
end

-- static_world use for editor module,only data needed
function util.start_static_world(packages)
-- local config = {Physics = create_physic()}
	local world = ecs.get_schema({Physics={}}, packages)
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
