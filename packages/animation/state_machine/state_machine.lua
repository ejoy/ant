local ecs = ...
local world = ecs.world
local timer = world:interface "ant.timer|timer"

local function get_transmit_merge(e, tt_duration)
	local timepassed = 0
	return function (deltatime)
		timepassed = timepassed + deltatime
		local current_pose = e.animation.current
		if timepassed > tt_duration then
			e.animation.current = current_pose[#current_pose]
			return true
		end
		local scale = math.max(0, math.min(1, timepassed / tt_duration))
		for i = 1, #current_pose-1 do
			current_pose[i].weight = current_pose[i].init_weight * (1 - scale)
		end
		current_pose[#current_pose].weight = scale
		return false
	end
end

local function play_animation(e, name, duration)
	local current_pose = e.animation.current
	if current_pose.type == "blend" then
		for i = 1, #current_pose do
			current_pose[i].init_weight = current_pose[i].weight
		end
		local ani = e.animation.anilist[name]
		current_pose[#current_pose+1] = {
			animation = ani,
			weight = 0,
			start_time = timer.current(),
		}
	else
		e.animation.current = {
			type = "blend",
			{
				animation = current_pose.animation,
				weight = 1,
				init_weight = 1,
				start_time = current_pose.start_time,
			},
			{
				animation = e.animation.anilist[name],
				weight = 0,
				init_weight = 0,
				start_time = timer.current(),
			}
		}
	end
	e.state_machine.transmit_merge = get_transmit_merge(e, duration * 1000.)
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

local function current_animation(current)
	if current.type == 'blend' then
		return current[#current].animation
	else
		return current.animation
	end
end

function m.set_state(e, name)
	if e.animation and e.animation.anilist[name] and e.state_machine then
		local current_ani = current_animation(e.animation.current)
		if current_ani.name == name then
			return
		end
		local statecfg = e.state_machine
		local traget_transmits = statecfg.transmits[current_ani.name]
		if traget_transmits and traget_transmits[name] then
			play_animation(e, name, traget_transmits[name].duration)
			return true
		end
	end
end

function m.play(e, name, time)
	if e.animation and e.animation.anilist[name]  then
		local current_ani = current_animation(e.animation.current)
		if current_ani.name == name then
			return
		end
		play_animation(e, name, time)
		return true
	end
end
