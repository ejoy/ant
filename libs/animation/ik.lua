local ecs = ...
local world = ecs.world

local ikmodule = require "hierarchy.ik"

local mathutil = (import_package "math").util
local ms = (import_package "math").stack

local ik = ecs.component_struct "ik" {
	target 		= mathutil.create_component_vector(),
	pole_vector = mathutil.create_component_vector(),
	mid_axis 	= mathutil.create_component_vector(),
	weight 		= 0.0,
	soften 		= 0.0,
	twist_angle = 0.0,
}

function ik:init()
	self.start_joint = -1
	self.mid_joint = -1
	self.end_joint = -1
end


local ik_sys = ecs.system "ik_system"
ik_sys.depend "animation_system"
ik_sys.dependby "skinning_system"

function ik_sys:update()
	for _, eid in world:each("ik") do
		local e = world[eid]
		local ik = e.ik
		local mat = ms({type="srt", s=e.scale, r=e.rotation, t=e.position}, "m")
		ikmodule.do_ik(mat, assert(e.skeleton), {
			target = ms(ik.target, "m"),
			pole_vector = ms(ik.pole_vector, "m"),
			mid_axis = ms(ik.mid_axis, "m"),
			weight = ik.weight,
			soften = ik.soften,
			twist_angle = ik.twist_angle,
		})
	end
end