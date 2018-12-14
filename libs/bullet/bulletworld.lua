
local bullet_module = require "bullet"

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

function bullet_world:create_planeShape( nx, ny, nz, distance)
	return self.world:new_shape("plane", nx, ny, nz, distance)
end

function bullet_world:create_sphereShape( radius)
	return self.world:new_shape("sphere", radius)
end

function bullet_world:create_capsuleShape( radius, height, axis)
	return self.world:new_shape("capsule", radius, height, axis)
end

function bullet_world:create_cubeShape(sx, sy, sz)
	return self.world:new_shape("cube", sx, sy, sz)
end

function bullet_world:create_cylinderShape( radius,up,axis)
    return self.world:new_shape("cylinder",radius,up,axis)
end 

function bullet_world:create_terrainShape(grid_width,grid_height,imgData,grid_scale,height_scale,min_height,max_height,
                                          axis,data_type,bflipQuadEdges)
    return self.world:new_shape("terrain",grid_width, grid_height ,imgData, 
                                          grid_scale, height_scale, min_height,max_height,
                                          axis, data_type, false )
end 

function bullet_world:create_compoundShape(btworld)
	return self.world:new_shape("compound")
end

-- 多重 type string 判断，影响性能,不过为非密集型，问题不大
function bullet_world:create_shape(type, arg)
	if type == "plane" then
		return self.world:new_shape(type, arg.nx, arg.ny, arg.nz, arg.dist)
	elseif type == "sphere" then
		return self.world:new_shape(type, arg.radius)
	elseif type == "capsule" then
		return self.world:new_shape(type, arg.radius, arg.height, arg.axis)
	elseif type == "cube" or type == "box" then
		return self.world:new_shape("cube", arg.sx, arg.sy, arg.sz)
	elseif type == "cylinder" then 
		return self.world:new_shape(type, arg.radius, arg.height, arg.axis)
	elseif type == "compound" then
		return self.world:new_shape(type)
	end
end


function bullet_world:create_object(shape, obj_idx,pos,rot)
    return self.world:new_obj(shape,obj_idx,pos,rot)
end 
function bullet_world:delete_object(object)
   -- todo: object must search all it's shape and delete
   -- 1. remove object from world first if it's in world
   -- 2. delete child shape first
   -- 3. delete object 
    return self.world:del_obj( object )
end 

function bullet_world:add_object( object )
    return self.world:add_obj( object )
end 
function bullet_world:remove_object( object )
	-- check if invalid(worldArrayIndex <=-1), return 
	return self.world:remove_obj(object)
end 

-- rotation by quaternion
function bullet_world:set_object_rotation(object, quat)
	return self.world:set_obj_rotation(object, quat  )
end 

-- rotation by euler angles
function bullet_world:set_object_angles(object, ax,ay,az )
	local rad = math.rad
	local rx ,ry,rz = rad(ax),rad(ay),rad(az)
	return self.world:set_obj_rot_euler(object, rx, ry,  rz )
end 
-- set object position 
function bullet_world:set_object_position(object, pos)
	return self.world:set_obj_position(object, pos  )
end 
-- set object scale
function bullet_world:set_object_scale(object,shape,scale)
	return self.world:set_shape_scale(object,shape,scale)
end 

-- info from component
local _pos = {}
function bullet_world:create_collider(type,info,obj_idx,pos,rot)
	local base_shape = self:create_shape("compound")
	local shape = self:create_shape(type,info)
	self.world:add_to_compound(base_shape,shape,{info.center[1],info.center[2],info.center[3]},rot)
	_pos[1] = pos[1] 
	_pos[2] = pos[2] 
	_pos[3] = pos[3] 
	-- local shape = self:create_shape(type,info)
	-- _pos[1] = info.center[1] + pos[1]
	-- _pos[2] = info.center[2] + pos[2]
	-- _pos[3] = info.center[3] + pos[3]
	local object = self:create_object(base_shape,obj_idx,_pos,rot)
	self:add_object( object )
	return object, base_shape 
end

-- delete and collider's object and it's sub shape 
function bullet_world:delete_collider(object,shape)
	self:delete_object(object)
end 


-- terrain is special, so give it an separate interface
function bullet_world:create_terrainCollider(terrain,info,obj_idx,pos,rot)
	local imgData = terrain:get_heightmap()

	--local terInfo = terrain:get_terrain_info()
	local grid_width = terrain:get_grid_width()
	local grid_length = terrain:get_grid_length()
	local grid_scale = terrain:get_width_scale()
	local height_scale = terrain:get_height_scale()
	local min_height = terrain:get_min_height()
	local max_height = terrain:get_max_height()

	local data_type = terrain:get_data_type()
	local upAxis = 1   -- default in our engine

	local shape = self:create_terrainShape( grid_width, grid_length ,imgData, 
									   grid_scale, height_scale, min_height,max_height,
									   upAxis, data_type, false )
									   
	local ofs = terrain:get_phys_offset()
	local obj = self:create_object( shape, obj_idx, { pos[1]+ofs[1], pos[2]+ofs[2], pos[3]+ofs[3]}, rot )
	self:add_object(obj)
	return obj,shape;
end 

function bullet_world:raycast( ray_start,ray_end )
	if self.debug then  end 
    return self.world:raycast( ray_start,ray_end )
end 

function bullet_world:collide_objects(objA,objB)
	return self.world:collide_objects(objA,objB)
end 

local function get_max_length(x,y,z)
	local len = x 
	if y > len then len = y end 
	if z > len then len = z end 
	return len 
end 
local function get_max_axis(x,y,z)
	local axis = 0
	if y> x and y> z then axis = 1 end 
	if z> x and z> y then axis = 2 end 
	return axis 
end 

local default_quat = {0,0,0,1}

-- special handy function, for lazy auto create component collider 
function bullet_world:add_component_collider(world,eid,type,ms, s_info)
	local Physics = self or world.args.Physics 
	-- component and collider info edit by editor 
	local c_type = type 
	local s,tag = string.find(type,"_collider")
	if(tag == nil ) then 
		if type == "box" or type == "cube" then type = "box" end 
        c_type = "collider"
	else
		type = string.sub(type,0,s-1) 
	end  

	local entity = world[eid]
	if entity[c_type] == nil then 
		world:add_component(eid, c_type)
	end 

	if s_info then 
		-- overwrite ,old entity.info will be gc later , or do copy 
		if s_info.type == nil then s_info.type = type end   -- verify check
		entity[c_type].info = s_info 
	else 
		entity[c_type].info.type = type 
	end    

	local rot, pos, scale 
	if ms then 
		pos = ms(entity.position,"T")
		rot = ms(entity.rotation,"T")
		scale = ms(entity.scale,"T")
	else 
		pos = {0,0,0}  rot = {0,0,0}  scale = {1,1,1}
	end 

	local r_scale = scale[1]
	if scale[2] > r_scale then r_scale = scale[2] end 
	if scale[3] > r_scale then r_scale = scale[3] end 


	local bounding_info = entity.mesh.assetinfo.handle.bounding
	local shape_info = entity[c_type].info    

	-- make sure shape info suply by ouside or serialization doc, if not exist auto calc
	-- for sizer 
	-- if s_info == nil then  
	-- 	if type == "box" or type == "cube" then 
	-- 		shape_info.sx = (bounding_info.aabb.max[1] - bounding_info.aabb.min[1])*0.5*scale[1]
	-- 		shape_info.sy = (bounding_info.aabb.max[2] - bounding_info.aabb.min[2])*0.5*scale[2]
	-- 		shape_info.sz = (bounding_info.aabb.max[3] - bounding_info.aabb.min[3])*0.5*scale[3]
	-- 	elseif type == "sphere" then 
	-- 		shape_info.radius = bounding_info.sphere.radius *r_scale
	-- 	elseif type == "capsule" or type == "cylinder" then 
	-- 		local xl = (bounding_info.aabb.max[1] - bounding_info.aabb.min[1])*0.5*r_scale
	-- 		local yl = (bounding_info.aabb.max[3] - bounding_info.aabb.min[3])*0.5*r_scale
	-- 		local radius = xl 
	-- 		if xl < yl then radius = yl end 
	-- 		shape_info.height = (bounding_info.aabb.max[2] - bounding_info.aabb.min[2])*0.5*r_scale
	-- 		shape_info.radius = radius 
	-- 		shape_info.axis = 1 
	-- 	end 
	-- 	shape_info.center = {0,0,0}		
	-- 	local cx = (bounding_info.aabb.max[1] + bounding_info.aabb.min[1])*0.5*scale[1]
	-- 	local cy = (bounding_info.aabb.max[2] + bounding_info.aabb.min[2])*0.5*scale[2]
	-- 	local cz = (bounding_info.aabb.max[3] + bounding_info.aabb.min[3])*0.5*scale[3]      
	-- 	shape_info.center = { cx,cy,cz }
	-- else
	-- 	if type == "box" or type == "cube" then 
	-- 		shape_info.sx = shape_info.sx*scale[1]
	-- 		shape_info.sy = shape_info.sy*scale[2]
	-- 		shape_info.sz = shape_info.sz*scale[3]
	-- 	elseif type == "sphere" then 
	-- 		shape_info.radius = shape_info.radius *r_scale
	-- 	elseif type == "capsule" or type == "cylinder" then 
	-- 		r_scale = 0
	-- 		if shape_info.axis == 0 then 
	-- 			r_scale = scale[2] if scale[3] >r_scale then r_scale = scale[3] end 
	-- 		elseif shape_info.axis == 1 then 
	-- 			r_scale = scale[3] if scale[1] >r_scale then r_scale = scale[1] end 
	-- 		elseif shape_info.axis == 2 then 
	-- 			r_scale = scale[1] if scale[2] >r_scale then r_scale = scale[2] end 
	-- 		end 
	-- 		shape_info.radius =  shape_info.radius* r_scale 
	-- 		shape_info.height = shape_info.height* scale[shape_info.axis+1]
	-- 	end 
	-- end 

	-- if ms then 
	-- 	local mat = ms( {type="srt", s= {1,1,1} , r= entity.rotation, t={0,0,0} }, "P")
	-- 	local nc  = ms( shape_info.center,mat,"*P")
	-- 	--local nc = ms( bounding_info.sphere.center,mat,"*P")
	-- 	--shape_info.center = ms(nc,"T")
	-- else 
	-- 	-- special tested ,not correct at all type 
	-- 	shape_info.center[1] = bounding_info.sphere.center[1]
	-- 	shape_info.center[2] = bounding_info.sphere.center[3]
	-- 	shape_info.center[3] = bounding_info.sphere.center[2]
	-- end 
	------------------------------------------------------------------
	-- for auto mode 
	if s_info == nil then  
		if type == "box" or type == "cube" then 
			shape_info.sx = (bounding_info.aabb.max[1] - bounding_info.aabb.min[1])*0.5
			shape_info.sy = (bounding_info.aabb.max[2] - bounding_info.aabb.min[2])*0.5
			shape_info.sz = (bounding_info.aabb.max[3] - bounding_info.aabb.min[3])*0.5
		elseif type == "sphere" then 
			shape_info.sx = (bounding_info.aabb.max[1] - bounding_info.aabb.min[1])*0.5
			shape_info.sy = (bounding_info.aabb.max[2] - bounding_info.aabb.min[2])*0.5
			shape_info.sz = (bounding_info.aabb.max[3] - bounding_info.aabb.min[3])*0.5
			shape_info.radius = get_max_length(shape_info.sx,shape_info.sy,shape_info.sz )
			scale[1] = r_scale  scale[2] = r_scale  scale[3] = r_scale     -- set max scale 
			-- some boundind_info radius > 2*real radius,so we need calculate 
			-- shape_info.radius = bounding_info.sphere.radius 
		elseif type == "capsule" or type == "cylinder" then 
			local xl = (bounding_info.aabb.max[1] - bounding_info.aabb.min[1])*0.5
			local yl = (bounding_info.aabb.max[2] - bounding_info.aabb.min[2])*0.5
			local zl = (bounding_info.aabb.max[3] - bounding_info.aabb.min[3])*0.5
		    -- set max axis as default axis ,we do not known the correct axis from modeler 
			local axis = get_max_axis(xl,yl,zl)  -- or manually set main axis
			local radius,height = 0,0
			--axis = 2
			if axis == 0 then 
				height = xl  radius = yl 
				if zl  > radius then radius = zl end  
			elseif axis == 1 then 
				height = yl  radius = xl 
				if zl > radius then radius = zl end  
			elseif axis == 2 then 
				height = zl  radius = xl 
				if yl > radius then radius = yl end  
			end 	
			shape_info.axis   = axis 
			shape_info.radius = radius 
			shape_info.height = height 
			-- scale[1] = r_scale  scale[2] = r_scale  scale[3] = r_scale     -- set max scale 
		end 
		shape_info.center = {0,0,0}		
		local cx = (bounding_info.aabb.max[1] + bounding_info.aabb.min[1])*0.5
		local cy = (bounding_info.aabb.max[2] + bounding_info.aabb.min[2])*0.5
		local cz = (bounding_info.aabb.max[3] + bounding_info.aabb.min[3])*0.5
		shape_info.center = { cx,cy,cz }
	end 

	shape_info.isTrigger = true
	shape_info.obj_idx = eid   -- or any combine mode 

	shape_info.obj, shape_info.shape = Physics:create_collider( type ,shape_info, eid, pos , default_quat ) 
	-- Physics:set_object_position( shape_info.obj, {pos[1],pos[2] + 10,pos[3] } )	
	Physics:set_object_angles( shape_info.obj, rot[1], rot[2], rot[3] )  --defer ajust, not add seperator function for create_*
	Physics:set_object_scale( shape_info.obj,shape_info.shape, scale )

	-- tested method and data 
	-- Physics:remove_object( shape_info.obj )
	-- Physics:set_object_rotation(shape_info.obj, {rx,ry,rz,rw})

    -- Physics:set_object_angles( shape_info.obj, rot[1], rot[2], rot[3] ) 
	-- Physics:add_object( shape_info.obj )
	-- pos[1] = pos[1] + shape_info.center[1] 
	-- pos[2] = pos[2] + shape_info.center[2] 
	-- pos[3] = pos[3] + shape_info.center[3] 
	-- Physics:set_object_position( shape_info.obj, pos  )
end 

-- special handy function, for lazy auto create component terrain collider 
function bullet_world:add_component_terCollider(world,eid,type,ms)
	local Physics = self or world.args.Physics 
	-- component and collider info edit by editor 
	local c_type = type 
	local s,tag = string.find(type,"_collider")
	if(tag == nil ) then 
        c_type = "collider"
	else
		type = string.sub(type,0,s-1) 
	end  

	local entity = world[eid]
	if entity[c_type] == nil then 
		world:add_component(eid, c_type)
	end 

	local terrain_obj = entity.terrain.terrain_obj 
	local shape_info = entity[c_type].info
	shape_info.type = "terrain"

	local rot, pos
	if ms then 
		pos = ms(entity.position,"T")
		rot = ms(entity.rotation,"T")
	else 
		pos = {0,0,0} rot = {1,1,1}
	end 	
	shape_info.obj, shape_info.shape = 
	Physics:create_terrainCollider(terrain_obj ,shape_info, eid, pos, {0,0,0,1} )
	-- Physics:set_object_angles( shape_info.obj, rot[1], rot[2], rot[3] )  --not need
end 


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
		local cu 	= require "render.components.util"
		local material = { content= {}, }
		cu.load_material( material,{"line.material",})
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


------ usage -------------

-- [ === normal usage ===]
-- world:add_component(bunny_eid, "box_collider")	
-- local shape_info = bunny.box_collider.info
-- shape_info.center[1] = 0  shape_info.center[2] = 0  shape_info.center[3] = 0
-- shape_info.sx = 5         shape_info.sy = 5         shape_info.sz = 5
-- shape_info.obj_idx = bunny_eid   -- or any combine mode 
-- --convert bunny position from stack pid to {...}
-- shape_info.obj, shape_info.shape = Physics:create_collider("box",shape_info, bunny_eid, {-32,-22.5,-32}, {0,0,0,1} )
-- handle obj,shape ,delete after entity or component destroy 

-- detail see in add_entity_phy_system.lua buny mesh part

-- [ === auto mode usage === ]
-- auto create component and collider for an entity, 
-- use it when you unserialize data from docfile,
-- or auto make collider for entity 
-- Physics:add_component_collider(world,bunny_eid,"box",ms)

-- detail see in PVPScene.lua 

--------------------------------------------------
-- [ === manaully ,single shape combine usage === ]
-- do some test following
-- local btw = bullet_world.new()
-- local shape_plane = btw:create_planeShape(0,1,0,0)

-- single function mode 
-- btw:create_cylinderShape(6,2,1)
-- btw:create_sphereShape(5)
-- btw:create_capsuleShape(2,6,2)
-- btw:create_compoundShape()

-- combine one function mode
-- btw:create_shape("capsule",{ radius = 10} )

-- create object 
-- local object_plane = btw:create_object(shape_plane,100,{0,1,0},{0,0,0,1} )
-- btw:add_object(object_plane)

-- do check 
-- local rayFrom = { 1.5, 20, 1.5 }
-- local rayTo = {  1.5, -5, 1.5 }
-- local hit, result = btw:raycast(rayFrom, rayTo)

-- local print_r = function(name,x,y,z)
-- 	print(name..": ", string.format("%10.6f",x), string.format("%10.6f",y), string.format("%10.6f",z) )
-- end 
-- local function print_raycast_result(result)
-- 	print(  "object user index : ", result.useridx)
-- 	print(  "     hit fraction : ", result.hit_fraction)

-- 	print_r(" hit object point : ", result.hit_pt_in_WS[1], result.hit_pt_in_WS[2], result.hit_pt_in_WS[3])
-- 	print_r("       hit normal : ", result.hit_normal_in_WS[1], result.hit_normal_in_WS[2], result.hit_normal_in_WS[3])
-- 	print(  "     filter group : ", result.filter_group)
-- 	print(  "      filter mask : ", result.filter_mask)
-- 	print(  "            flags : ", result.flags)    
-- end
-- if hit then 
-- 	print_raycast_result(result)
-- else 
--     print("--- hit nothing, rayInfo = ", result )
-- end 


----------------------------------------------------------------
-- usage:

-- local bullet_system = require "bulletworld"
-- local bullet_world = bullet_system.new()

-- bullet_world:create_planeShape(0,1,0,0)

--local plane = bullet_world:create_planeShape(0,1,0,0)

-- ecs.component "collider" {
--   info { type = "box", center= {0,0,0},sx = 1,sy=1,sz= 1} }	
--}

-- ecs.component "box_collider" {
--     info { center= {0,0,0},sx = 1,sy=1,sz= 1} }
-- }
-- buny as entity add component "BoxCollider" 
-- local  info = buny.box_collider.info
-- bullet_world:add_component_collider(ecs.world,bunny_eid,"box",ms,info)

-- bullet_world = nil 

-- local bullet_world = require "bulletworld"

return bullet_world
