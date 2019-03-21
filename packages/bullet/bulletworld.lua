
local bullet_module = require "bullet"
local fs = require "filesystem"

local mathpkg = import_package "ant.math"
local ms = mathpkg.stack
local math_adapter = require "math3d.adapter"

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


-- -- terrain is special, so give it an separate interface
-- function bullet_world:create_terrainCollider(terrain,info,obj_idx,pos,rot)
-- 	local imgData = terrain:get_heightmap()

-- 	--local terInfo = terrain:get_terrain_info()
-- 	local grid_width = terrain:get_grid_width()
-- 	local grid_length = terrain:get_grid_length()
-- 	local grid_scale = terrain:get_width_scale()
-- 	local height_scale = terrain:get_height_scale()
-- 	local min_height = terrain:get_min_height()
-- 	local max_height = terrain:get_max_height()

-- 	local data_type = terrain:get_data_type()
-- 	local upAxis = 1   -- default in our engine

-- 	local shape = self:create_terrainShape( grid_width, grid_length ,imgData, 
-- 									   grid_scale, height_scale, min_height,max_height,
-- 									   upAxis, data_type, false )
									   
-- 	local ofs = terrain:get_phys_offset()
-- 	local obj = self:new_obj(shape, obj_idx, { pos[1]+ofs[1], pos[2]+ofs[2], pos[3]+ofs[3]}, rot )
-- 	self:add_obj(obj)
-- 	return obj, shape
-- end 

-- local default_quat = ms:ref "quaternion" (0, 0, 0, 1)
-- function bullet_world:init_collider_component(collidercomp, obj_idx, srt, offset)		
-- 	local collider = collidercomp.collider
-- 	collider.obj_idx = obj_idx

-- 	local s, r, t = srt.s, srt.r, srt.t
-- 	local pos = offset and ms(t, offset, "+m") or ms(t, "m")

-- 	local shapeinfo = collidercomp.shape
-- 	local obj, shape = self:create_collider(shapeinfo.type, shapeinfo, obj_idx, pos, ~default_quat)

-- 	collider.handle = obj
-- 	shapeinfo.handle = shape

-- 	self:set_obj_rot_euler(obj, ms(r, ms.toquat))
-- 	self:set_shape_scale(obj, ms(s, "m"))
-- end

-- function bullet_world:add_component_collider(world, eid, collidername, offset)	
-- 	local e = world[eid]
-- 	self:init_collider_component(e[collidername], eid, e.transform, offset)
-- end 

-- special handy function, for lazy auto create component terrain collider 
-- function bullet_world:add_component_terCollider(world,eid,type,ms)
-- 	local Physics = self or world.args.Physics 
-- 	-- component and collider info edit by editor 
-- 	local c_type = type 
-- 	local s,tag = string.find(type,"_collider")
-- 	if(tag == nil ) then 
--         c_type = "collider"
-- 	else
-- 		type = string.sub(type,0,s-1) 
-- 	end  

-- 	local entity = world[eid]
-- 	if entity[c_type] == nil then 
-- 		world:add_component(eid, c_type)
-- 	end 

-- 	local terrain_obj = entity.terrain.terrain_obj 
-- 	local shape_info = entity[c_type].info
-- 	shape_info.type = "terrain"

-- 	local rot, pos
-- 	if ms then 
-- 		pos = ms(entity.position,"T")
-- 		rot = ms(entity.rotation,"T")
-- 	else 
-- 		pos = {0,0,0} rot = {1,1,1}
-- 	end 	
-- 	shape_info.obj, shape_info.shape = 
-- 	Physics:create_terrainCollider(terrain_obj ,shape_info, eid, pos, {0,0,0,1} )
-- 	-- Physics:set_obj_rot_euler( shape_info.obj, rot[1], rot[2], rot[3] )  --not need
-- end 


function bullet_world:enable_debug(enable)
	assert("not implement!")
end

return bullet_world
