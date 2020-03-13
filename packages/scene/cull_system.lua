--luacheck: ignore self
local ecs = ...
local world = ecs.world

local mathbaselib = require "math3d.baselib"

local math = import_package "ant.math"
local mu = math.util

local cull_sys = ecs.system "cull_system"
cull_sys.require_system "primitive_filter_system"

function cull_sys:cull()
	for _, tag in ipairs {"main_queue", "csm", "pickup"} do
		for _, queue_eid in world:each(tag) do
			local e = world[queue_eid]
			local filter = e.primitive_filter

			local camera = world[e.camera_eid].camera
			local vp = mu.view_proj(camera)
			local frustum = mathbaselib.new_frustum(vp)
			
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