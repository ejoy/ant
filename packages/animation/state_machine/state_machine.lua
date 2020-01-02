local ecs = ...
local world = ecs.world

local assetpkg = import_package "ant.asset"
local assetmgr = assetpkg.mgr

local timer = import_package "ant.timer"

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
	e.state_chain.transmit_merge = get_transmit_merge(e, duration * 1000.)
	local current = timer.from_counter(timer.get_sys_counter())
	for _, aniref in ipairs(targetpose) do
		aniref.start_time = current
	end
end

local m = ecs.policy "state_chain"
m.require_component "state_chain"
m.require_system "state_machine"

ecs.component_alias("state_chain", "resource")

local sm = ecs.system "state_machine"
sm.step "animation_state"
sm.require_system "animation_system"

function sm:update()
	for _, eid in world:each "state_chain" do
		local e = world[eid]
		if e.state_chain.transmit_merge then
			if e.state_chain.transmit_merge(timer.deltatime) then
				e.state_chain.transmit_merge = nil
			end
		end
		local newtarget = e.state_chain.target
		if newtarget then
			local current_pose = e.animation.current_pose
			local statecfg = assetmgr.get_resource(e.state_chain.ref_path)
			local traget_transmits = statecfg.transmits[current_pose[#current_pose].name]
			if traget_transmits and traget_transmits[newtarget] then
				play_animation(e, newtarget, traget_transmits[newtarget].duration)
			end
			e.state_chain.target = nil
		end
	end
end
