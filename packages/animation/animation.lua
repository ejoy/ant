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
	.upaxis		"vector"{0, 1, 0, 0}	-- local space, same as IKTwoBoneJob's mid_axis
	.twist_angle"real" 	(0.0)
	.joints		"string[]"{}			-- type == 'aim', #joints == 1, type == 'two_bone', #joints == 3, with start/mid/end
	["opt"].soften "real" (0.0)
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
	local pose = {}
	for name, ani in pairs(self.anilist) do
		local aniref = {}
		aniref.handle = asset.get_resource(ani.ref_path).handle
		aniref.sampling_cache = ani_module.new_sampling_cache()
		aniref.start_time = 0
		aniref.duration = aniref.handle:duration() * 1000. / ani.scale
		aniref.max_time = ani.looptimes > 0 and (ani.looptimes * aniref.duration) or math.maxinteger
		pose[name] = {name = name, aniref}
	end
	self.pose = pose
	local birth_pose = self.pose[self.birth_pose]
	birth_pose.weight = 1
	self.current_pose = {birth_pose}
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
			type = ikdata.type,
			target = ms(invtran, ikdata.target, "*m"),
			pole_vector = ms(invtran, ikdata.pole_vector, "*m"),
			
			updir = ms(ikdata.updir, "m"),
			weight = ikdata.weight,
			twist_angle = ikdata.twist_angle,
			joints = ikdata.joints,
		}

		if ikdata.type == "aim" then
			c.forward = ms(ikdata.forward, "m")
			c.offset = ms(ikdata.offset, "m")
		else
			assert(ikdata.type == "two_bone")
			c.soften = ikdata.soften
		end

		cache[#cache+1] = c
	end
	return cache
end

function anisystem:sample_animation_pose()
	local current_time = timer.current()
	for _, eid in world:each "animation" do
		local e = world[eid]
		local animation = e.animation
		local fix_root <const> = true
		local ske = asset.get_resource(e.skeleton.ref_path).handle
		for _, pose in ipairs(animation.current_pose) do
			for _, aniref in ipairs(pose) do
				local localtime = current_time - aniref.start_time
				if localtime > aniref.max_time then
					aniref.ratio = 0
				else
					aniref.ratio = localtime % aniref.duration / aniref.duration
				end
			end
		end

		ani_module.setup(ske)

		ani_module.do_animation(animation.current_pose, "blend", nil, fix_root)
		--ani_module.do_ik(prepare_ik(e.transform, animation.ik))

		ani_module.get_result(animation.result, fix_root)
	end
end
