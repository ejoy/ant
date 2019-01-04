local util = {}; util.__index = util

local mu = require "math.util"
local ms = require "math.stack"

local cu = require "render.components.util"
local commonutil = require "common.util"

local function move_position(p, dir, speed)
	ms(p, p, dir, {speed}, "*+=")
end

function util.move(camera, dx, dy, dz)
	local xdir, ydir, zdir = ms(camera.rotation, "bPPP")

	local eye = camera.position
	move_position(eye, xdir, dx)
	move_position(eye, ydir, dy)
	move_position(eye, zdir, dz)

	-- if c == "a" or c == "A" then
	-- 	move_position(eye, xdir, move_step)
	-- elseif c == "d" or c == "D" then					
	-- 	move_position(eye, xdir, -move_step)
	-- elseif c == "w" or c == "W" then					
	-- 	move_position(eye, zdir, move_step)
	-- elseif c == "s" or c == "S" then					
	-- 	move_position(eye, zdir, -move_step)
	-- elseif c == "q" or c == "Q" then
	-- 	move_position(eye, ydir, move_step)
	-- elseif c == "e" or c == "E" then
	-- 	move_position(eye, ydir, -move_step)					
	-- end
end

function util.rotate(camera, dx, dy)
	local rot = camera.rotation

	local rot_result = ms(rot, {dy, dx, 0, 0}, "+T")

	rot_result[1] = mu.limit(rot_result[1], -89.9, 89.9)
	ms(rot, rot_result, "=")
end

function util.focus_point(world, pt)
	local maincamera = world:first_entity("main_camera")
	local newrot = ms(pt, maincamera.position, "-neP")
	ms(maincamera.rotation, newrot, "=")
end

function util.focus_selected_obj(world, eid)
	local entity = assert(world[eid])

	if not cu.is_entity_visible(assert(entity)) then
		return 
	end

	local mesh = entity.mesh
	if mesh == nil or mesh.assetinfo == nil then
		return 
	end

	local handle = mesh.assetinfo.handle

	local bounding = handle.groups[1].bounding			
	if nil == bounding then
		return 
	end

	local aabb = commonutil.deep_copy(bounding.aabb)
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
	local worldmat = ms({type="srt", s=entity.scale, r=entity.rotation, t=entity.position}, "m")
	math3dlib.transform_aabb(worldmat, aabb)
	local center = ms(aabb.max, aabb.min, "-", {0.5}, "*P")
	local radius = ms(aabb.max, aabb.min, "-1.P")

	local camera = world:first_entity("main_camera")
	local dir = ms(center, camera.position, "-nP")

	ms(camera.position, center, dir, radius, "*-=")
	ms(camera.rotation, dir, "D=")
end

return util