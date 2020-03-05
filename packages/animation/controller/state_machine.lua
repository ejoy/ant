local ecs = ...
local world = ecs.world
local timer = world:interface "ant.timer|timer"
local fs = require "filesystem"

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

local function current_animation(current)
	if current.type == 'blend' then
		return current[#current].animation
	else
		return current.animation
	end
end

local function play_animation(e, name, duration)
	local current_ani = current_animation(e.animation.current)
	if current_ani and current_ani.name == name then
		return
	end
	local current_pose = e.animation.current
	if current_pose.type == "blend" then
		for i = 1, #current_pose do
			current_pose[i].init_weight = current_pose[i].weight
		end
		local ani = e.animation.anilist[name]
		current_pose[#current_pose+1] = {
			animation = ani,
			weight = 0,
            ratio = 0,
		}
	elseif current_pose.animation then
		e.animation.current = {
			type = "blend",
			{
				animation = current_pose.animation,
				weight = 1,
				init_weight = 1,
				ratio = current_pose.ratio,
			},
			{
				animation = e.animation.anilist[name],
				weight = 0,
				init_weight = 0,
				ratio = 0,
			}
		}
	else
		e.animation.current = {
			animation = e.animation.anilist[name],
            ratio = 0,
		}
		return
	end
	e.state_machine.transmit_merge = get_transmit_merge(e, duration * 1000.)
end

local function set_state(e, name, time)
	local sm = e.state_machine
	local info = sm.nodes[name]
	if info.execute then
		play_animation(e, info:execute(), time)
	else
		play_animation(e, name, time)
	end
	sm.current = name
end

local m = ecs.policy "animation_controller.state_machine"
m.require_component "animation"
m.require_component "state_machine"
m.require_system "state_machine"
m.require_transform "state_machine"

local m = ecs.component "state_machine"
		.current "string"
["opt"]	.file "respath"
		.nodes "state_machine_node{}"

function m:init()
	if self.file then
		assert(fs.loadfile(self.file))(self.nodes)
	end
	return self
end

ecs.component "state_machine_node"
	.transmits "state_machine_transmits{}"

ecs.component "state_machine_transmits"
	.duration "real"

local m = ecs.transform "state_machine"
m.input "state_machine"
m.output "animation"

function m.process(e)
	e.animation.current = {}
	set_state(e, e.state_machine.current, 0)
end

local m = ecs.system "state_machine"
m.require_system "animation_system"
m.require_interface "ant.timer|timer"

function m:animation_state()
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
	local sm = e.state_machine
	if e.animation and sm and sm.nodes[name] then
		if sm.current == name then
			return
		end
		if not sm.current then
			set_state(e, name, 0)
			return
		end
		local info = sm.nodes[sm.current]
		if info and info.transmits[name] then
			set_state(e, name, info.transmits[name].duration)
			return true
		end
	end
end

function m.play(e, name, time)
	if e.animation and e.animation.anilist[name]  then
		if e.state_machine then
			e.state_machine.current = nil
			play_animation(e, name, time)
		else
			e.animation.current = {
				animation = e.animation.anilist[name],
				ratio = 0,
			}
		end
		return true
	end
end

function m.set_value(e, name, key, value)
	local sm = e.state_machine
	if not sm or not sm.nodes then
		return
	end
	local node = sm.nodes[name]
	if not node then
		return
	end
	node[key] = value
	if sm.current == name then
		set_state(e, name, 0)
	end
end
