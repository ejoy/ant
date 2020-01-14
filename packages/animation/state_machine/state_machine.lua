local ecs = ...
local world = ecs.world
local timer = world:interface "ant.timer|timer"

local function get_transmit_merge(e, tt_duration)
	local timepassed = 0
	return function (deltatime)
		timepassed = timepassed + deltatime
		if timepassed > tt_duration then
			local current_pose = e.animation.current_pose
			current_pose[1] = current_pose[#current_pose]
			current_pose[1].weight = 1
			for i = 2, #current_pose do
				current_pose[i] = nil
			end
			return true
		end
		local scale = math.max(0, math.min(1, timepassed / tt_duration))
		local current_pose = e.animation.current_pose
		for i = 1, #current_pose-1 do
			current_pose[i].weight = current_pose[i].init_weight * (1 - scale)
		end
		current_pose[#current_pose].weight = scale
		return false
	end
end

local function play_animation(e, name, duration)
	local current_pose = e.animation.current_pose
	for i = 1, #current_pose do
		current_pose[i].init_weight = current_pose[i].weight
	end
	local targetpose = e.animation.pose[name]
	targetpose.weight = 0
	current_pose[#current_pose+1] = targetpose
	e.state_machine.transmit_merge = get_transmit_merge(e, duration * 1000.)
	local current = timer.current()
	for _, aniref in ipairs(targetpose) do
		aniref.start_time = current
	end
end

local m = ecs.policy "state_machine"
m.require_component "state_machine"
m.require_system "state_machine"

ecs.component "state_machine_target"
	.duration "real"
ecs.component_alias("state_machine_node", "state_machine_target{}")
ecs.component "state_machine"
	.transmits "state_machine_node{}"

local sm = ecs.system "state_machine"
sm.require_system "animation_system"
sm.require_interface "ant.timer|timer"

function sm:animation_state()
	local delta = timer.delta()
	for _, eid in world:each "state_machine" do
		local e = world[eid]
		if e.state_machine.transmit_merge then
			if e.state_machine.transmit_merge(delta) then
				e.state_machine.transmit_merge = nil
			end
		end
	end
end

local m = ecs.interface "animation"
m.require_interface "ant.timer|timer"

function m.set_state(e, name)
	if e.animation and e.animation.pose[name] and e.state_machine then
		local current_pose = e.animation.current_pose
		if current_pose.name == name then
			return
		end
		local statecfg = e.state_machine
		local traget_transmits = statecfg.transmits[current_pose[#current_pose].name]
		if traget_transmits and traget_transmits[name] then
			play_animation(e, name, traget_transmits[name].duration)
			return true
		end
	end
end

function m.play(e, name, time)
	if e.animation and e.animation.pose[name]  then
		local current_pose = e.animation.current_pose
		if current_pose.name == name then
			return
		end
		play_animation(e, name, time)
		return true
	end
end
