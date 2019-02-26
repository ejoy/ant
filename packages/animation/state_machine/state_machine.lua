local ecs = ...
local world = ecs.world

ecs.component "state"
	.name "string"
	.pose "pose"

ecs.component "transmit_target"
	.targetname "string"
	.duration "real"

ecs.component "transmit"	
	.targets "transmit_target[]"

local state_chain = ecs.component_alias("state_chain", "resource")

function state_chain:init()
	local statecfg = self.assetinfo
	self.target = statecfg.main_entry
	return self
end

local timer = import_package "ant.timer"
local aniutil = require "util"

local sm = ecs.system "state_machine"
sm.dependby "animation_system"

function sm:init()

end

local function get_pose(chain, name)
	for _, s in ipairs(chain) do
		if s.name == name then
			return s.pose
		end
	end
end


local function get_transmit_merge(entity, targettransmit)
	local timepassed = 0
	return function (deltatime)
		local tt_duration = targettransmit.duration
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
		local statecfg = e.state_chain.assetinfo
		local anicomp = assert(e.animation)
		local anipose = anicomp.pose

		local chain = statecfg.chain

		local transmit_merge = state_chain.transmit_merge
		if transmit_merge then
			if transmit_merge(timer.deltatime) then
				state_chain.transmit_merge = nil
				anipose.define = anipose.transmit.targetpose
				anipose.transmit = nil
			end
		else
			local traget_transmits = statecfg.transmits[state_chain.target]
			if traget_transmits then
				for _, transmit in ipairs(traget_transmits) do
					if transmit.can_transmit(e, _G) then
						local newtarget = transmit.targetname
						state_chain.target = newtarget
						local targetpose = get_pose(chain, newtarget)
						anipose.transmit = {
							source_weight = 1,
							target_weight = 0,
							targetpose = targetpose
						}
			
						aniutil.play_animation(anicomp, targetpose)
						state_chain.transmit_merge = get_transmit_merge(e, transmit)
						break
					end
				end
			else
				if _G.DEBUG then
					print("[state machine]: there are not transmit targets for current target> ", state_chain.target)
				end
			end
		end
	end
end