local ecs = ...
local world = ecs.world

ecs.import "scene.filter.filter_system"

local math3d_baselib = require "math3d.baselib"
local mu = require "math.util"

local cull_sys = ecs.system "cull_system"
cull_sys.singleton "math_stack"
cull_sys.depend "primitive_filter_system"
cull_sys.dependby "lighting_primitive_filter_system"

function cull_sys:update()
	local ms = self.math_stack
	for _, eid in world:each("primitive_filter") do
		local e = world[eid]
		local filter = e.primitive_filter		
		local view, proj = mu.view_proj_matrix(ms, e)
		-- plane is in world space
		local planes = math3d_baselib.extract_planes(ms(view, proj, "*m"))
		
		local newfilter_result = {}
		local results = filter.result
		for _, prim in ipairs(results) do			
			local psrt = prim.srt
			local srt = ms({type="srt",s=psrt.s, r=psrt.r, t=psrt.t}, "m")
			local function need_filter_out()
				local group = prim.mgroup
				local bounding = group.bounding
				if bounding == nil then
					return false
				end

				local aabb = math3d_baselib.transform_aabb(srt, bounding.aabb)
				return "outside" == math3d_baselib.intersect(planes, aabb)				
			end

			if not need_filter_out() then
				table.insert(newfilter_result, prim)			
			end
		end

		if #newfilter_result ~= #results then
			filter.result = newfilter_result
		end
	end
end