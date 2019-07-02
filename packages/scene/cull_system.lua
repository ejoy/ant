--luacheck: ignore self
local ecs = ...
local world = ecs.world

local mathbaselib = require "math3d.baselib"

local math = import_package "ant.math"
local mu = math.util
local ms = math.stack

local cull_sys = ecs.system "cull_system"

cull_sys.depend "primitive_filter_system"

function cull_sys:update()
	local mq = world:first_entity "main_queue"
	local filter = mq.primitive_filter
	local camera = mq.camera
	local _, _, viewproj = ms:view_proj(camera, camera.frustum, true)
	-- plane is in world space
	local planes = mathbaselib.extract_planes()
	local frustum = mathbaselib.new_frustum(ms(proj, view, "*m"))
	
	local results = filter.result
	for _, resulttarget in pairs(results) do
		local boundings = {}
		for _, prim in ipairs(resulttarget) do
			local tb = prim.transformed_bounding
			boundings[#boundings+1] = tb or true
		end

		local visible_set = frustum:interset_list(boundings)
		assert(#visible_set == #boundings)

		resulttarget.visible_set = visible_set
	end
end