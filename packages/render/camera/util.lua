local util = {}; util.__index = util

local math = import_package "ant.math"
local ms = math.stack

local cu = require "components.util"

local function deep_copy(t)
	if type(t) == "table" then
		local tmp = {}
		for k, v in pairs(t) do
			tmp[k] = deep_copy(v)
		end
		return tmp
	end
	return t
end

function util.focus_point(world, pt)
	local maincamera = world:first_entity("main_camera")
	local camera = maincamera.camera
	ms(camera.viewdir, pt, camera.eyepos, "-n=")
end

local function mesh_bounding_sphere(entity)
	local mesh = entity.mesh		
	if mesh then
		local assetinfo = mesh.assetinfo
		if assetinfo then
			local handle = assetinfo.handle
			local groups = handle.groups
			if #groups > 0 then
				local bounding = groups.bounding
				if bounding then
					local aabb = deep_copy(bounding.aabb)
					--[[
						here is what this code do:
							1. get world mat in this entity ==> worldmat 
							2. transform aabb ==> aabb
							3. get aabb center and square aabb radius ==> center, radius
							4. calculate current camera position to aabb center direction ==> dir
							5. calculate new camera position ==> 
									newposition = center - radius * dir, here, minus dir is for negative the direction
							6. change camera direction as new direction
				
					]]
					local math3dlib = require "math3d.baselib"
					local worldmat = ms:create_srt_matrix(entity.transform)
					math3dlib.transform_aabb(worldmat, aabb)
					local center = ms(aabb.max, aabb.min, "-", {0.5}, "*P")
				
					--[[
						init stack size: 2
						1. '-': dir = max - min	-> [dir]		1(stack size)
						2. '1': duplicate dir	-> [dir, dir]	2
						3. '.': dot(dir, dir)	-> [dot result]	1
						4. 'P': pop result
					]]
					local radius = ms(aabb.max, aabb.min, "-1.P")

					return {center = center, radius = radius}
				end
			end

		end
	end

	return {center = entity.transform.t, radius = 100}
end

function util.focus_selected_obj(world, eid)
	local entity = assert(world[eid])

	if not cu.is_entity_visible(assert(entity)) then
		return 
	end

	local sphere = mesh_bounding_sphere(entity)

	local camera_entity = world:first_entity("main_camera")
	local camera = camera_entity.camera
	ms(camera.viewdir, sphere.center, camera.eyepos, "-n=")
	ms(camera.eyepos, sphere.center, camera.viewdir, sphere.radius, "*-=")
	return true
end

return util