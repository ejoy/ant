local ecs = ...
local world = ecs.world

local asset = import_package "ant.asset".mgr
local ani_module = require "hierarchy.animation"

local mathpkg = import_package "ant.math"
local ms = mathpkg.stack

--there are 2 types in ik_data, which are 'two_bone'(IKTwoBoneJob) and 'aim'(IKAimJob).
ecs.component "ik_data"
	.type		"string"("aim")			-- can be 'two_bone'/'aim'
	.target 	"vector"{0, 0, 0, 1}	-- model space
	.pole_vector"vector"{0, 0, 0, 0}	-- model space
	.twist_angle"real" 	(0.0)
	.joints		"string[]"{}			-- type == 'aim', #joints == 1, type == 'two_bone', #joints == 3, with start/mid/end
	["opt"].mid_axis"vector" {0, 0, 1, 0}
	["opt"].soften "real" 	(0.0)
	["opt"].up_axis"vector" {0, 1, 0, 0}
	["opt"].forward "vector"{0, 0, 1, 0}-- local space
	["opt"].offset "vector" {0, 0, 0, 0}-- local space

ecs.component "ik"
	.jobs 'ik_data[]'

ecs.component "animation_content"
	.ref_path "respath"
	.scale "real" (1)
	.looptimes "int" (0)

local t_ani = ecs.transform "ani_result"
t_ani.input "skeleton"
t_ani.output "animation"
function t_ani.process(e)
	local skehandle = asset.get_resource(e.skeleton.ref_path).handle
	e.animation.result = ani_module.new_bind_pose(#skehandle)
	e.animation.ske = skehandle
end

local ap = ecs.policy "animation"
ap.require_component "skeleton"
ap.require_component "animation"
ap.require_transform "ani_result"

ap.require_system "animation_system"

local anicomp = ecs.component "animation"
	.anilist "animation_content{}"
	.birth_pose "string"
	.ik "ik"

function anicomp:init()
	for name, ani in pairs(self.anilist) do
		ani.handle = asset.get_resource(ani.ref_path).handle
		ani.sampling_cache = ani_module.new_sampling_cache()
		ani.start_time = 0
		ani.duration = ani.handle:duration() * 1000. / ani.scale
		ani.max_time = ani.looptimes > 0 and (ani.looptimes * ani.duration) or math.maxinteger
		ani.name = name
	end
	local birth_pose = self.anilist[self.birth_pose]
	birth_pose.weight = 1
	self.current = {birth_pose}
	return self
end

ecs.component_alias("skeleton", "resource")

local anisystem = ecs.system "animation_system"
anisystem.require_interface "ant.timer|timer"

local timer = world:interface "ant.timer|timer"

local function prepare_ik(transform, ikcomp)
	local invtran = ms(transform, "iP")
	local cache = {}
	for _, ikdata in ipairs(ikcomp.jobs) do
		local c = {
			type		= ikdata.type,
			target 		= ms(invtran, ikdata.target, "*m"),
			pole_vector = ms(invtran, ikdata.pole_vector, "*m"),
			weight		= ikdata.weight,
			twist_angle = ikdata.twist_angle,
			joints 		= ikdata.joints,
		}

		if ikdata.type == "aim" then
			c.forward	= ms(ikdata.forward, "m")
			c.up_axis	= ms(ikdata.up_axis, "m")
			c.offset	= ms(ikdata.offset, "m")
		else
			assert(ikdata.type == "two_bone")
			c.soften	= ikdata.soften
			c.mid_axis	= ms(ikdata.mid_axis, "m")
		end

		cache[#cache+1] = c
	end
	return cache
end

function anisystem:sample_animation_pose()
	local current_time = timer.current()
	for _, eid in world:each "animation" do
		local fix_root <const> = true
		local e = world[eid]
		local animation = e.animation
		ani_module.setup(animation.ske)
		for _, ani in ipairs(animation.current) do
			local localtime = current_time - ani.start_time
			local ratio = 0
			if localtime <= ani.max_time then
				ratio = localtime % ani.duration / ani.duration
			end
			ani_module.do_sample(ani.sampling_cache, ani.handle, ratio, ani.weight)
		end
		local pose = animation.current
		ani_module.do_blend("blend", #pose)
		ani_module.do_ik(animation.result, prepare_ik(e.transform, animation.ik))
		ani_module.get_result(animation.result, fix_root)
	end
end
