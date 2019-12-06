local ecs = ...
local world = ecs.world

local assetpkg = import_package "ant.asset"
local assetmgr = assetpkg.mgr

local timer = import_package "ant.timer"

local function play_animation(pose)
	local current = timer.from_counter(timer.get_sys_counter())
	for _, aniref in ipairs(assert(pose)) do
		aniref.start_time = current
	end
end

local state_chain = ecs.component "state_chain" {depend = "animation"}
	.ref_path "respath"

function state_chain:init()
	local res = assetmgr.load(self.ref_path)
	self.target = res.main_entry
	return self
end

local function get_pose(e, name)
	return e.animation.pose[name]
end

function state_chain:postinit(e)
	local pose = get_pose(e, self.target)
	pose.weight = 1
	e.animation.current_pose = {pose}
end

local sm = ecs.system "state_machine"
sm.dependby "animation_system"

local function get_transmit_merge(entity, tt_duration)
	local timepassed = 0
	return function (deltatime)
		timepassed = timepassed + deltatime

		if timepassed > tt_duration then
			return true
		end

		local weight = math.max(0, math.min(1, timepassed / tt_duration))
		local current_pose = assert(entity.animation.current_pose)
		current_pose[1].weight = 1 - weight
		current_pose[2].weight = weight

		return false
	end
end

function sm:update()
	for _, eid in world:each "state_chain" do
		local e = world[eid]
		local statecfg = assetmgr.get_resource(e.state_chain.ref_path)
		local transmit_merge = statecfg.transmit_merge
		if transmit_merge then
			if transmit_merge(timer.deltatime) then
				statecfg.transmit_merge = nil
				table.remove(e.animation.current_pose, 1)
			end
		else
			if e.animation.target then
				local traget_transmits = statecfg.transmits[e.animation.current_pose[1].name]
				local newtarget = e.animation.target
				if traget_transmits and traget_transmits[newtarget] then
					local targetpose = get_pose(e, newtarget)
					table.insert(e.animation.current_pose, targetpose)
					e.animation.current_pose[1].weight = 1
					e.animation.current_pose[1].weight = 0
					play_animation(targetpose)
					statecfg.transmit_merge = get_transmit_merge(e, traget_transmits[newtarget].duration * 1000.)
				else
					if _G.DEBUG then
						print("[state machine]: there are not transmit targets for current target> ", e.state_chain.target)
					end
				end
				e.state_chain.target = nil
			end
		end
	end
end
