local ecs = ...
local world = ecs.world

local mathpkg = import_package "ant.math"
local ms = mathpkg.stack

-- local ik_module = require "hierarchy.ik"

-- local fixroot <const> = true

-- function ik_sys:do_ik()
-- 	for _, eid in world:each "ik" do
-- 		local e = world[eid]

-- 		for _, ikdata in ipairs(e.ik.jobs) do
-- 			ik_module.do_ik(e.skeleton.handle, e.pose_result.result, fixroot, prepare_ik_data(e.transform, ikdata))
-- 		end
-- 	end
-- end

-- local mathadapter_util = import_package "ant.math.adapter"
-- local math3d_adapter = require "math3d.adapter"
-- mathadapter_util.bind("animation", function ()
-- 	ik_module.do_ik = math3d_adapter.matrix(ms, ik_module.do_ik, 1)
-- end)