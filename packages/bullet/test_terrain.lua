
package.path = package.path .. ";./packages/bullet/?.lua"

local terrainmodule = require "terrain"
local math3d = require "math3d"
local ms = math3d.new()

local bt = require "bulletworld"
local btworld = bt.new()

local terraininfo = {
	width  = 400,
	length = 400,
	height = 385,
	
	grid_width  = 513,
	grid_length = 513,
	
	num_layers = 4,
	
	heightmap = {
		bits   = 8,	-- get from ref_path?
		ref_path = "packages/resources.binary/terrain/pvp1.raw",
		path = "packages/resources.binary/terrain/pvp1.raw",
	},
	
	uv0_scale  = 50, --80*0.625,   -- 140
	uv1_scale  = 1,
}

local terrain 		= terrainmodule.create(terraininfo)

local heightmapdata = terrain:hieghtmap_data()
local bounding 		= terrain:calc_heightmap_bounding()
local aabb = bounding.aabb
local bouding_height = aabb.max[2] - aabb.min[2]
local heightmap_scale = terraininfo.height / bouding_height
local width_scale = terraininfo.width / terraininfo.grid_width
local length_scale = terraininfo.length / terraininfo.grid_length

local shapes = {
	cylinder 	= btworld:new_shape("cylinder", {radius=16, height=3, axis=1}),
	plane 		= btworld:new_shape("plane", {normal={0, 1, 0}, distance=0}),
	terrain 	= btworld:new_shape("terrain", {
							width = terraininfo.grid_width, height = terraininfo.grid_length, 
							heightmap_scale = heightmap_scale, 
							min_height = aabb.min[2], max_height = aabb.max[2],
							heightmapdata = heightmapdata,
							up_axis = 1, flip_quad_edges=false})
}

btworld:set_shape_scale(shapes.terrain, ms({width_scale, 1, length_scale}, "m"))

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
print("plane useridx:", useridx)
local object_plane = btworld:new_obj(shapes.plane, useridx, ms({0,-200,0}, "m"), ms({0,0,0,1}, "m"))
--btworld:add_obj(object_plane)

useridx = gen_user_idx()
print("cylinder eid : ", useridx)
local obj_cylinder = btworld:new_obj(shapes.cylinder, useridx, ms({0,-200,0}, "m"), ms({0,0,0,1}, "m"))
--btworld:add_obj(obj_cylinder)

useridx = gen_user_idx()
print("terrain eid : ", useridx)

local center = bounding.sphere.center
local offset = {center[1] * width_scale, center[2] * heightmap_scale, center[3] * length_scale}
local obj_terrain = btworld:new_obj(shapes.terrain, useridx, ms(offset, "m"), ms({0,0,0,1}, "m"))
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

-- check correctness
for i = -200,200 do 
		local x,y = i*width_scale, i*length_scale 
		local rayFrom = { x+(256*width_scale),  1000, y+(256*length_scale) }
		local rayTo   = { x+(256*width_scale), -1000, y+(256*length_scale) }
		local hit3, result3 = btworld:raycast(ms(rayFrom, "m"), ms(rayTo, "m"))
		print("-- i ("..i..")")
		print(" x, z : "..rayFrom[1].."  "..rayFrom[3])    
		-- local height =  terrain:raw_height( i+256,i+256 )
		-- local ix = x+(256*width_scale)
		-- local iy = y+(256*length_scale)
		-- local hit,height1 = terrain:height( ix,iy );
		-- print("height, height1 = ", height,height1)
		print("-- raycast result: ")
		if hit3  then 
			print_raycast_result(result3)
		else 
			print("--- hit nothing, rayInfo = ", result3 )
		end 
		print("")
end 		

print("")

math3d.reset(ms)

btworld = nil		-- gc world
bullet = nil		-- gc bullet sdk

