local ecs = ...
local world = ecs.world
local schema = world.schema

schema:type "aniref"
	.idx "int"	-- TODO: need use name to referent which animation
	.weight "real"

schema:type "pose"
	.anilist "aniref[]"
	.name "string"

schema:type "state"
	.name "string"
	.pose "pose"

schema:type "transmit_target"
	.targetname "string"
	.duration "real"

schema:type "transmit"	
	.targets "transmit_target[]"

schema:type "state_chain"
	.chain "state[]"
	.transmits "transmit{}"
	.target "string"

local timer = import_package "ant.timer"
local aniutil = require "util"

local state_chain = ecs.component "state_chain"
function state_chain.init()
	return {		
		transmit_merge = nil,
	}
end

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
		local weight = math.max(0, math.min(1, timepassed / tt_duration))
		timepassed = timepassed + deltatime

		local anicomp = entity.animation
		local transmit = assert(anicomp.pose.transmit)
		transmit.source_weight = 1 - weight
		transmit.target_weight = weight
	end
end

function sm:update()
	for _, eid in world:each "state_chain" do
		local e = world[eid]
		local state_chain = e.state_chain
		local anicomp = assert(e.animation)
		local anipose = anicomp.pose

		local chain = state_chain.chain

		local transmit_merge = state_chain.transmit_merge
		if transmit_merge then
			if transmit_merge(timer.deltatime) then
				state_chain.transmit_merge = nil
				anipose.define = anipose.transmit.targetpose
				anipose.transmit = nil
			end
		else
			local traget_transmits = state_chain.transmits[state_chain.target]
			if traget_transmits then
				for _, transmit in ipairs(traget_transmits) do
					if transmit.can_transmit(e, _G) then
						local newtarget = transmit.name
						state_chain.target = newtarget
						local targetpose = get_pose(chain, newtarget)
						anipose.transmit = {
							source_weight = 0,
							target_weight = 0,
							targetpose = targetpose
						}
			
						aniutil.play_animation(anicomp, targetpose)
						state_chain.transmit = get_transmit_merge(e, transmit)
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