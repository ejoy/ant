--luacheck: ignore self
local ecs = ...
local world = ecs.world

local mathbaselib = require "math3d.baselib"

local math = import_package "ant.math"
local mu = math.util
local ms = math.stack

local renderpkg = import_package "ant.render"
local camerautil= renderpkg.camera

local cull_sys = ecs.system "cull_system"

cull_sys.depend "primitive_filter_system"

function cull_sys:update()
	for _, tag in ipairs {"main_queue", "shadow", "pickup"} do
		for _, queue_eid in world:each(tag) do
			local e = world[queue_eid]
			local filter = e.primitive_filter

			local camera = camerautil.get_camera(world, e.camera_tag)
			local _, _, viewproj = ms:view_proj(camera, camera.frustum, true)
			local frustum = mathbaselib.new_frustum(ms, viewproj)
			
			local results = filter.result
			for _, resulttarget in pairs(results) do
				local num = resulttarget.cacheidx - 1
				if num > 0 then
					local visible_set = frustum:intersect_list(resulttarget, num)
					resulttarget.visible_set = visible_set
				end
			end
		end
	end
end