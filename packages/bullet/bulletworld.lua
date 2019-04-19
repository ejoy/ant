
local bullet_module = require "bullet"
local bullet_sdk = bullet_module.new()

local bullet_world = {}
bullet_world.__index = function (tbl, key)	
	local bw = tbl.world
	return bullet_world[key] or 
		function (t, ...)
			return bw[key](bw, ...)
		end
end

function bullet_world.new()
    return setmetatable({
		world = bullet_sdk:new_world()
	}, bullet_world)
end 

function bullet_world:delete()
   self.world:del_bullet_world()	
   self:delete_debug_drawer(true)
end

function bullet_world:create_collider(shapehandle, obj_idx, pos, rot)
	local object = self:new_obj(shapehandle, obj_idx, pos, rot)
	self:add_obj(object)
	return object
end

function bullet_world:enable_debug(enable)
	assert("not implement!")
end

return bullet_world
