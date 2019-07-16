--luacheck: ignore self
local ecs = ...
local world = ecs.world

local mathbaselib = require "math3d.baselib"

local math = import_package "ant.math"
local mu = math.util
local ms = math.stack

local cull_sys = ecs.system "cull_system"

cull_sys.depend "primitive_filter_system"

local bounding_cache = {}

function cull_sys:update()
	for _, tag in ipairs {"main_queue", "shadow"} do
		local e = world:first_entity(tag)
		if e then
			local filter = e.primitive_filter
			local camera = e.camera
			local _, _, viewproj = ms:view_proj(camera, camera.frustum, true)
			local frustum = mathbaselib.new_frustum(ms, viewproj)
			
			local results = filter.result
			for _, resulttarget in pairs(results) do
				local num = resulttarget.cacheidx - 1
				for i=1, num do
					local prim = resulttarget[i]
					local tb = prim.transformed_bounding
					bounding_cache[i] = tb == nil and true or tb
				end

				bounding_cache.n = num
				if num > 0 then
					local visible_set = frustum:intersect_list(bounding_cache, num)
					assert(#visible_set == num)

					resulttarget.visible_set = visible_set
				end
			end
		end
	end
end