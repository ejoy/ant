local ecs = ...
local world = ecs.world
local w = world.w

local rhwi      = import_package "ant.hwi"
local iviewport = ecs.require "ant.render|viewport.state"
local iom = ecs.require "ant.objcontroller|obj_motion"
local camera_ctrl = ecs.system "camera_ctrl"
local math3d = require "math3d"
local mathpkg   = import_package "ant.math"
local mu, mc = mathpkg.util, mathpkg.constant

local camera = {
	x = 0,
	y = 0,
	z = 0,
	yaw = 0,
	pitch = 45,
	distance = 1,
	min = {},
	max = {},
}

local camera_change_meta = { __index = camera }

local camera_change = setmetatable( {} , camera_change_meta )

local function camera_set(_, what, v)
	local oldv = camera[what]
	if oldv == v then
		camera_change[what] = nil
	else
		camera_change[what] = v
	end
end

local camera_vchange = {}
local vchange = setmetatable({}, { __newindex = camera_vchange })

local camera_accesor = setmetatable({ delta = vchange } , {
	__index = camera_change,
	__newindex = camera_set,
	__pairs = function() return next, camera end,
})

local function delta_change()
	for k,v in pairs(camera_vchange) do
		if rawget(camera_change, k) == nil then
			camera_change[k] = camera[k] + v
		end
		camera_vchange[k] = nil
	end
end

local pitch = { axis = mc.XAXIS }
local yaw = { axis = mc.YAXIS }

local function clamp(what)
	local min = camera.min[what]
	if min and camera[what] < min then
		camera[what] = min
	end
	local max = camera.max[what]
	if max and camera[what] > max then
		camera[what] = max
	end
end

function camera_ctrl:start_frame()
	local main_queue = w:first "main_queue camera_ref:in render_target:in"
	local main_camera <close> =	world:entity(main_queue.camera_ref, "camera:in")
	
	camera.view_rect = main_queue.render_target.view_rect
	camera.vpmat = main_camera.camera.viewprojmat

	if next(camera_vchange) then
		local dx = camera_vchange.x
		local dz = camera_vchange.y
		camera_vchange.x = nil
		camera_vchange.y = nil
		delta_change()
		if dx or dz then
			dx = dx or 0
			dz = dz or 0
			local r = math.rad(-camera_change.yaw)
			local sin_r = math.sin(r)
			local cos_r = math.cos(r)
			local z1 = dz * cos_r + dx * sin_r
			local x1 = dx * cos_r - dz * sin_r
			camera_change.x = camera.x + x1
			camera_change.y = camera.y - z1
		end
	end
	if next(camera_change) == nil then
		return
	end

	for k,v in pairs(camera_change) do
		camera[k] = v
		camera_change[k] = nil
	end
	clamp "x"
	clamp "y"
	clamp "z"
	clamp "distance"
	clamp "yaw"
	clamp "pitch"

	pitch.r = math.rad(camera.pitch)
	yaw.r = math.rad(camera.yaw)
	local r = math3d.mul(math3d.quaternion(yaw), math3d.quaternion(pitch))
	local t = math3d.vector(0,0,0-camera.distance,1)
	t = math3d.transform(r, t, 1)
	t = math3d.add(t, math3d.vector(camera.x, camera.z, -camera.y))
	iom.set_srt(main_camera, nil, r, t)
end

local icamera_ctrl = camera_accesor

local XZ_PLANE <const> = math3d.constant("v4", {0, 1, 0, 0})

function camera_accesor.screen_to_world(x, y)
	local x, y = iviewport.scale_xy(x, y)
	local viewport_mat = icamera_ctrl.vpmat
	local view_rect = icamera_ctrl.view_rect
    local ndcpt = mu.pt2D_to_NDC({x, y}, view_rect)
    ndcpt[3] = 0
    local p0 = mu.ndc_to_world(viewport_mat, ndcpt)
    ndcpt[3] = 1
    local p1 = mu.ndc_to_world(viewport_mat, ndcpt)
    local _ , p = math3d.plane_ray(p0, math3d.sub(p0, p1), XZ_PLANE, true)
	if p then
		local x, y = math3d.index(p, 1, 3)
		return x, -y
	end
end

function camera_ctrl:init_world()
	icamera_ctrl.min.x = -10
	icamera_ctrl.max.x = 10
	icamera_ctrl.min.y = -10
	icamera_ctrl.max.y = 10
	icamera_ctrl.min.pitch = 20
	icamera_ctrl.max.pitch = 80
	icamera_ctrl.distance = 10
end

return camera_accesor
