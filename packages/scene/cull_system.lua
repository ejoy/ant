--luacheck: ignore self
local ecs = ...
local world = ecs.world

local math3d_baselib = require "math3d.baselib"

local math = import_package "ant.math"
local mu = math.util
local ms = math.stack

local cull_sys = ecs.system "cull_system"

cull_sys.depend "primitive_filter_system"
cull_sys.dependby "lighting_primitive_filter_system"

function cull_sys:update()	
	for _, eid in world:each("camera") do
		local e = world[eid]		
		local filter = e.primitive_filter
		local view, proj = mu.view_proj_matrix(e)
		-- plane is in world space
		local planes = math3d_baselib.extract_planes(ms(proj, view, "*m"))
		
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