local ecs = ...
local world = ecs.world

local assetpkg = import_package "ant.asset"
local assetmgr = assetpkg.mgr

ecs.component "state"
	.name "string"
	.pose "pose"

ecs.component "transmit_target"
	.targetname "string"
	.duration "real"

ecs.component "transmit"
	.targets "transmit_target[]"

local state_chain = ecs.component "state_chain" {depend = "animation"}
	.ref_path "respath"

function state_chain:init()
	local res = assetmgr.load(self.ref_path)
	self.target = res.main_entry
	return self
end

local function get_pose(e, name)
	for _, s in ipairs(e.animation.pose) do
		if s.name == name then
			return s
		end
	end
end

function state_chain:postinit(e)
	e.animation.current_pose = get_pose(e, self.target)
end

local timer = import_package "ant.timer"
local aniutil = require "util"

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
		local anicomp = entity.animation
		local transmit = assert(anicomp.pose.transmit)
		transmit.source_weight = 1 - weight
		transmit.target_weight = weight

		return false
	end
end

function sm:update()
	for _, eid in world:each "state_chain" do
		local e = world[eid]
		local statecfg = assetmgr.get_resource(e.state_chain.ref_path)
		local anicomp = assert(e.animation)
		local anipose = anicomp.current_pose

		local transmit_merge = statecfg.transmit_merge
		if transmit_merge then
			if transmit_merge(timer.deltatime) then
				statecfg.transmit_merge = nil
				anipose.current_pose = anipose.transmit.targetpose
				anipose.transmit = nil
			end
		else
			if e.state_chain.target then
				local traget_transmits = statecfg.transmits[anipose.name]
				local newtarget = e.state_chain.target
				if traget_transmits and traget_transmits[newtarget] then
					local targetpose = get_pose(e, newtarget)
					anipose.transmit = {
						source_weight = 1,
						target_weight = 0,
						targetpose = targetpose
					}

					aniutil.play_animation(anicomp, targetpose)
					statecfg.transmit_merge = get_transmit_merge(e, traget_transmits[newtarget].duration)
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