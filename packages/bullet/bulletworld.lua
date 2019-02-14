
local bullet_module = require "bullet"
local fs = require "filesystem"

local mathpkg = import_package "ant.math"
local math3d = require "math3d"
local ms = mathpkg.stack

local bullet_sdk = bullet_module.new()

local bullet_world = {}
bullet_world.__index = bullet_world
-- bullet_world.__gc = bullet_world.delete

function bullet_world.new()
    local btw = {}
    btw.world = bullet_sdk:new_world()
    local bullet_world_inst = setmetatable( btw, bullet_world )   			
    return bullet_world_inst 
end 

-- call it when application shutdown ,recommend
--  reuse bullet_world in all game time
-- change levelmap ,delete/create new world is not recommend
function bullet_world:delete()
   self.world:del_bullet_world()	
   self:delete_debug_drawer(true)
end 

-- function bullet_world:create_planeShape( nx, ny, nz, distance)
-- 	return self.world:new_shape("plane", nx, ny, nz, distance)
-- end

-- function bullet_world:create_sphereShape( radius)
-- 	return self.world:new_shape("sphere", radius)
-- end

-- function bullet_world:create_capsuleShape( radius, height, axis)
-- 	return self.world:new_shape("capsule", radius, height, axis)
-- end

-- function bullet_world:create_boxShape(sx, sy, sz)
-- 	return self.world:new_shape("cube", sx, sy, sz)
-- end

-- function bullet_world:create_cylinderShape( radius,up,axis)
--     return self.world:new_shape("cylinder",radius,up,axis)
-- end 

-- function bullet_world:create_terrainShape(grid_width,grid_height,imgData,grid_scale,height_scale,min_height,max_height,
--                                           axis,data_type,bflipQuadEdges)
--     return self.world:new_shape("terrain",grid_width, grid_height ,imgData, 
--                                           grid_scale, height_scale, min_height,max_height,
--                                           axis, data_type, bflipQuadEdges )
-- end 

-- function bullet_world:create_compoundShape()
-- 	return self.world:new_shape("compound")
-- end

function bullet_world:create_shape(type, arg)
	return self.world:new_shape(type, arg)

	-- if type == "plane" then
	-- 	return self.world:new_shape(type, arg.nx, arg.ny, arg.nz, arg.dist)
	-- elseif type == "sphere" then
	-- 	return self.world:new_shape(type, arg.radius)
	-- elseif type == "capsule" then
	-- 	return self.world:new_shape(type, arg.radius, arg.height, arg.axis)
	-- elseif type == "box" then
	-- 	return self.world:new_shape(type, arg.sx, arg.sy, arg.sz)
	-- elseif type == "cylinder" then 
	-- 	return self.world:new_shape(type, arg.radius, arg.height, arg.axis)
	-- elseif type == "compound" then
	-- 	return self.world:new_shape(type)
	-- end
end


function bullet_world:create_object(shape, obj_idx, pos, rot)
    return self.world:new_obj(shape, obj_idx, pos, rot)
end

function bullet_world:delete_shape(shape)
	if shape then
		self.world:del_shape(shape)
	end
end

function bullet_world:delete_object(object)	
	if object then
		self.world:del_obj(object)
	end
end 

function bullet_world:add_object(object)
    return self.world:add_obj(object)
end 
function bullet_world:remove_object(object)
	return self.world:remove_obj(object)
end 

function bullet_world:set_object_rotation(object, quat)
	return self.world:set_obj_rotation(object, quat  )
end 

function bullet_world:set_object_angles(object, rot)	
	return self.world:set_obj_rot_euler(object, rot)
end 

function bullet_world:set_object_position(object, pos)
	return self.world:set_obj_position(object, pos)
end 

function bullet_world:set_object_scale(object, scale)
	return self.world:set_shape_scale(object, scale)
end

function bullet_world:create_collider(shapetype, shapeinfo, obj_idx, pos, rot)	
	local shape = self:create_shape(shapetype, shapeinfo)
	local object = self:create_object(shape, obj_idx, pos, rot)
	self:add_object(object)
	return object, shape
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
-- 	local obj = self:create_object(shape, obj_idx, { pos[1]+ofs[1], pos[2]+ofs[2], pos[3]+ofs[3]}, rot )
-- 	self:add_object(obj)
-- 	return obj, shape
-- end 

function bullet_world:raycast( ray_start,ray_end )
	if self.debug then  end 
    return self.world:raycast( ray_start,ray_end )
end 

function bullet_world:collide_objects(objA,objB)
	return self.world:collide_objects(objA,objB)
end  

local default_quat = math3d.ref("quaternion", ms)
default_quat(ms:quaternion(0,0,0,1))

function bullet_world:init_collider_component(collidercomp, obj_idx, srt, offset)		
	local collider = collidercomp.collider
	collider.obj_idx = obj_idx

	local s, r, t = srt[1], srt[2], srt[3]
	local pos = offset and ms(t, offset, "+m") or ms(t, "m")

	local shapeinfo = collidercomp.shape
	local obj, shape = self:create_collider(shapeinfo.type, shapeinfo, obj_idx, pos, ~default_quat)

	collider.handle = obj
	shapeinfo.handle = shape

	self:set_object_angles(obj, ms(r, "m"))
	self:set_object_scale(obj, ms(s, "m"))
end

function bullet_world:add_component_collider(world, eid, collidername, offset)
	world:add_component(eid, collidername)
	local e = world[eid]
	self:init_collider_component(e[collidername], eid, {e.scale, e.rotation, e.position}, offset)
end 

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
-- 	-- Physics:set_object_angles( shape_info.obj, rot[1], rot[2], rot[3] )  --not need
-- end 


-----------------------------------
-- debugDrawer
local function identify_transform( ms  )
	local args = {
		t = {0,0,0,1},
		r = {0,0,0,0},
		s = {1,1,1,1}
	}
	return ms( args.t,args.r,"dLm" )
end

function bullet_world:drawline( ray_start,ray_end,color )
    return self.world:drawline( ray_start,ray_end,color )
end 

function bullet_world:get_debug_info()
	return self.world:get_debug_info()
end 

function bullet_world:debug_clear_world()
	self.world:debug_clear_world()
end 

function bullet_world:delete_debug_drawer(shutdown)
	local bgfx = self.bgfx 
	if bgfx == nil then return end 

	if shutdown == true then 
		if self.vdecl then self.vdecl = nil end   -- userdata ?
		-- 2 frames rule, be careful of this rule(handle,data keep two frames time)
		if self.vbh  then bgfx.destroy( self.vbh ) end 
		if self.ibh then bgfx.destroy( self.ibh ) end 
		self.bgfx = nil 
	end 
	-- material support ref ?
	-- if self.prog then bgfx.destroy( self.prog ) end 
	self.prog = nil     -- framework prog,material mgr must provide ref manager mechanism 
	self.material = nil  
	self.debug = false 
end 

function bullet_world:create_debug_drawer(bgfx)
	self.bgfx = bgfx 
	local args = {
		{"POSITION",3,"FLOAT"},   
		--{"COLOR0", 4, "FLOAT"}, 
		{"COLOR0", 4, "UINT8", true },
	}
	local num = 1024 

	if self.vdecl == nil or self.vbh == nil or self.ibh == nil then 
		self.vdecl = bgfx.vertex_decl( args )		
		self.vbh = bgfx.create_dynamic_vertex_buffer( num, self.vdecl,"rwa" );
		self.ibh = bgfx.create_dynamic_index_buffer( num,"rwda" )
	end 

	if self.prog == nil then 
		local cu 	= import_package "ant.render" .components
		local material = { content= {}, }
		cu.add_material(material, "engine", fs.path "line.material")
		self.prog = material.content[1].materialinfo.shader.prog 
		self.material = material    -- how to destroy?
	end 

	self.world:create_debug_drawer();

	self.debug = true 
end 
-- first call,must provide bgfx renderer 
function bullet_world:set_debug_drawer(on_off,bgfx)
	local bgfx = self.bgfx or bgfx 
	if bgfx == nil then return end 
	if on_off == "off" then 
	   self:delete_debug_drawer(bgfx)
	   self.debug = false 
	   return 
	end 
	if on_off == "on" then 
		if self.debug == true then
			self:delete_debug_drawer(bgfx)
		end 
		self:create_debug_drawer(bgfx)
	end 
end 


function bullet_world:debug_draw_world( viewId, world,ms,mathu,fb )
	if self.debug == nil or self.debug == false then 
		return 
	end 
	local bgfx = self.bgfx or bgfx 
	if bgfx == nil or world == nil or ms == nil or mathu == nil then return end 

	local ts =os.clock()
	self.world:debug_begin_draw()
	local te =os.clock()

	local vbo,ibo,nv,ni = self:get_debug_info()

	local camera = world:first_entity("main_camera")
	local camera_view, camera_proj = mathu.view_proj_matrix( camera ) -- ms, camera )
	
	local prim_type =  "LINES" 
	local state =  bgfx.make_state( { CULL="CW", PT = prim_type ,
									 WRITE_MASK = "RGBAZ",
									 DEPTH_TEST	= "LEQUAL"
								    } , nil)        									-- for terrain

	bgfx.set_view_rect( viewId, 0, 0, fb.w,fb.h)
	bgfx.set_view_transform( viewId,ms(camera_view,"m"),ms(camera_proj,"m") )	
	bgfx.touch( viewId )

	bgfx.update( self.vbh, 0, {'!',vbo} ) 
	bgfx.update( self.ibh, 0, {ibo} )

	bgfx.set_state( state )
	bgfx.set_transform(identify_transform(ms))
	bgfx.set_vertex_buffer( self.vbh )
	bgfx.set_index_buffer( self.ibh )  
	bgfx.submit( viewId, self.prog)    -- 使用 index 不正常显示？ wrong update api usage

	self.world:debug_end_draw()
end 


return bullet_world
