local ecs = ...
local world = ecs.world

local asset = import_package "ant.asset".mgr
local timer = import_package "ant.timer"
local ani_module = require "hierarchy.animation"
local ik_module = require "hierarchy.ik"
local ms = import_package "ant.math".stack

ecs.component "animation_content"
	.ref_path "respath"
	.scale "real" (1)
	.looptimes "int" (0)

local m = ecs.transform "animation"
m.input "skeleton"
m.output "animation"
function m.process(e)
	local ske = e.skeleton
	local skehandle = asset.get_resource(ske.ref_path).handle
	local numjoints = #skehandle
	e.animation.aniresult = ani_module.new_bind_pose(numjoints)
	local pose = {}
	for name, ani in pairs(e.animation.anilist) do
		local aniref = {}
		aniref.handle = asset.get_resource(ani.ref_path).handle
		aniref.sampling_cache = ani_module.new_sampling_cache(numjoints)
		aniref.start_time = 0
		aniref.duration = aniref.handle:duration() * 1000. / ani.scale
		aniref.max_time = ani.looptimes > 0 and (ani.looptimes * aniref.durations) or math.maxinteger
		pose[name] = {name = name, aniref}
	end
	e.animation.pose = pose
	local pose = e.animation.pose[e.animation.birth_pose]
	pose.weight = 1
	e.animation.current_pose = {pose}
end

local m = ecs.policy "animation"
m.require_component "animation"
m.require_component "skeleton"
m.require_transform "animation"
m.require_system "animation_system"

ecs.component "animation"
	.anilist "animation_content{}"
	.birth_pose "string"

ecs.component_alias("skeleton", "resource")

local anisystem = ecs.system "animation_system"

function anisystem:sample_animation_pose()
	local current_time = timer.from_counter(timer.current_counter)
	for _, eid in world:each "animation" do
		local e = world[eid]
		local ske = asset.get_resource(e.skeleton.ref_path).handle
		local fix_root <const> = true

		local animation = e.animation
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
		ani_module.motion(ske, animation.current_pose, "blend", animation.aniresult, nil, fix_root)
	end
end
