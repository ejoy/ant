
package.path = package.path..';./clibs/terrain/?.lua;./test/?.lua;'
package.path = package.path..';./clibs/bullet/?.lua;'

local bgfx = require "bgfx"
local math_util = require "math.util"
local shaderMgr = require "render.resources.shader_mgr"
local camera_util = require "render.camera.util"
local render_cu = require "render.components.util"


local bullet_module = require "bullet"
local terrainClass = require "terrainclass"

local bullet = bullet_module.new()
local btworld = bullet:new_world()
local bu = require "lua.util"

local terrain = terrainClass.new() 
terrain:load( "assets/build/terrain/pvp1.lvl" )

local imgData = terrain:get_heightmap()
local grid_width = terrain:get_grid_width()
local grid_height = terrain:get_grid_length()
local grid_scale = terrain:get_width_scale()
local height_scale = terrain:get_height_scale()
local min_height = terrain:get_min_height()
local max_height = terrain:get_max_height()
local data_type = terrain:get_data_type()
local upAxis = 1

local terInfo = terrain:get_terrain_info()

local shapes = {
	cylinder = btworld:new_shape("cylinder", 16, 3, 1),
	plane = btworld:new_shape("plane", 0, 1, 0, 0),
	-- sphere = btworld:new_shape("sphere", 5),
	-- capsule = btworld:new_shape("capsule", 2, 6, 1),
	-- compound = btworld:new_shape("compound"),
	terrain = btworld:new_shape("terrain",grid_width, grid_height ,imgData, 
										  grid_scale, height_scale, min_height,max_height,
										  upAxis, data_type, false )
}

local function get_user_idx_op()
	local start_user_idx = 100
	return function ()
		local t = start_user_idx 
		start_user_idx = start_user_idx + 1
		return t
	end
end

local gen_user_idx = get_user_idx_op()

local useridx = gen_user_idx()
print("plane eid ="..useridx)
local object_plane = btworld:new_obj(shapes.plane, useridx, {0,-200,0}, {0,0,0,1})
--btworld:add_obj(object_plane)

useridx = gen_user_idx()
print("cylinder eid ="..useridx)
local obj_cylinder = btworld:new_obj(shapes.cylinder,useridx,{0,-200,0},{0,0,0,1})
--btworld:add_obj(obj_cylinder)

useridx = gen_user_idx()
print("terrain eid ="..useridx)
local ofs = terrain:get_phys_offset()
local obj_terrain = btworld:new_obj(shapes.terrain,useridx, {  ofs[1],ofs[2],ofs[3]}, {0,0,0,1} )
btworld:add_obj(obj_terrain)

local print_r = function(name,x,y,z)
	print(name..": ", string.format("%10.6f",x), string.format("%10.6f",y), string.format("%10.6f",z) )
end 

local function print_raycast_result(result)
	print("object user index : ", result.useridx)
	print("hit fraction :", result.hit_fraction)

	print_r("hit object point : ", result.hit_pt_in_WS[1], result.hit_pt_in_WS[2], result.hit_pt_in_WS[3])
	print_r("hit normal : ", result.hit_normal_in_WS[1], result.hit_normal_in_WS[2], result.hit_normal_in_WS[3])
	print("filter group : ", result.filter_group)
	print("filter mask : ", result.filter_mask)
	print("flags : ", result.flags)    
end


-- local f = io.open("lua_ter_shape.txt" ,"w+");
-- for y = 1,513 do 
-- 	local line = " ";
-- 	for x = 1,513 do 
-- 		local height =  terrain:get_raw_height( x-1,y-1 )
-- 		line = line.." "..string.format("%06.2f",height)
-- 	end 
-- 	f:write(line)
-- 	f:write("\r")
-- end 
-- f:close()


local height =  terrain:get_raw_height( 0,0 )
-- check correctness
for i = -200,200 do 
		local x,y = i*grid_scale, i*grid_scale 
		local rayFrom = { x+(256*grid_scale),  1000, y+(256*grid_scale) }
		local rayTo   = { x+(256*grid_scale), -1000, y+(256*grid_scale) }
		local hit3, result3 = btworld:raycast(rayFrom,rayTo)
		print("-- i ("..i..")")
		print(" x, z : "..rayFrom[1].."  "..rayFrom[3])    
		local height =  terrain:get_raw_height( i+256,i+256 )
		local ix = x+(256*grid_scale)
		local iy = y+(256*grid_scale)
		local hit,height1 = terrain:get_height( ix,iy );
		print("height, height1 = ", height,height1)
		print("-- raycast result: ")
		if hit3  then 
			print_raycast_result(result3)
		else 
			print("--- hit nothing, rayInfo = ", result3 )
		end 
		print("")
end 		

print("")

btworld = nil		-- gc world
bullet = nil		-- gc bullet sdk

