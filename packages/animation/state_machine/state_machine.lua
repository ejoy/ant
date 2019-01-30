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
	.script "resource"	--code for state transmit


local timer = import_package "ant.timer"
local aniutil = require "util"

local state_chain = ecs.component "state_chain"
function state_chain.init()
	return {
		current = "idle",
		target	= "",		
		transmit = nil,
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

local function find_target_state(transmit, targetstate)
	for _, t in ipairs(transmit.targets) do
		if t.name == targetstate then
			return t
		end
	end
end


local function get_transmit(script)
	if script then
		local antpm = require "antpm"
		local root = antpm.find(assert(script[1]))
		return require(root / script[2])
	end

	local timepassed = 0
	return function (ani, targettransmit, deltatime)
		local tt_duration = targettransmit.duration
		local weight = math.max(0, math.min(1, timepassed / tt_duration))
		timepassed = timepassed + deltatime

		local transmit = assert(ani.pose.transmit)
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

		local srcstate = state_chain.current
		local chain = state_chain.chain

		if state_chain.transmit then
			if state_chain.transmit(timer.deltatime) then
				state_chain.transmit = nil
				anipose.define = anipose.transmit.targetpose
				anipose.transmit = nil
			end
		elseif state_chain.target then
			local targetstate = state_chain.target
			local srcpose = get_pose(chain, srcstate)
			local targetpose = get_pose(chain, targetstate)
			assert(srcpose, string.format("invalid state:%s", srcstate))
			assert(targetpose, string.format("invalid state:%s", targetstate))

			local transmits = state_chain.transmits
			local transmit = transmits[srcstate]

			local target = find_target_state(transmit, targetstate)
			if target == nil then
				error(string.format("dest state:%s, not reachable!", targetstate))
			end

			anipose.transmit = {
				source_weight = 0,
				target_weight = 0,
				targetpose = targetpose
			}

			aniutil.play_animation(anicomp, targetpose)
			local op = get_transmit(state_chain.script)
			state_chain.transmit = function (deltatime)
				return op(anicomp, target, deltatime)
			end

			state_chain.target = nil
		end
	end
end