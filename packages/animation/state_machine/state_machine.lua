local ecs = ...
local world = ecs.world
local schema = world.schema

local animodule = require "hierarchy.animation"

schema.type "ani"
	.ani_idx "int"
	.weight "real"

schema.type "pose"
	.anilist "ani[]"
	.ratio 	"real"

local pose = ecs.component "pose"
function pose:init()
	self.bindpose = animodule.new_bind_pose()
end

schema.type "state"
	.name "string"
	.pose "pose"

schema.type "transmit_type"
	.name "string"
	.weight "real"

schema.type "transmit"
	.time "real"
	.src_transtype "transmit_type"
	.dst_translist "transmit_type{}"

schema.type "state_chain"
	.chain "state[]"
	.transmits "transmit{}"
	.script "resource"	--code for state transmit


local function get_pose(chain, name)
	for _, s in ipairs(chain) do
		if s.name == name then
			return s.pose
		end
	end
end

local state_chain = ecs.component "state_chain"
function state_chain.init()
	return {
		current = "idle",
		dest	= "",		
		transmit = nil,
	}
end

local sm = ecs.system "state_machine"
sm.dependby "animation_system"
sm.singleton "timer"

function sm:init()

end

local function get_transimit(script)
	if script then
		local antpm = require "antpm"
		local root = antpm.find(assert(script[1]))
		return require(root / script[2])
	end

	local timepassed = 0
	return function (srcinput, dstinput, ske, ani, transtime, dt)
		local anilist = ani.anilist

		timepassed = timepassed + dt
		local ratio = math.max(1, timepassed / transtime)
	
		local function blend_poses(srcinput, dstinput, ratio)
			local w1, p1 = srcinput.trantype.weight, srcinput.pose
			local w2, p2 = dstinput.trantype.weight, dstinput.pose

			local function gen_bind_pose(weight, pose)
				local anis = {}
				for _, aniidx in ipairs(pose.ani) do
					local ani = assert(anilist[aniidx])
					anis[#anis+1] = ani					
				end

				animodule.blend(ske, pose.ratio, anis, "blend", pose.bindpose)
				return pose.bindpose
			end

			local bp1, bp2 = gen_bind_pose(w1, p1), gen_bind_pose(w2, p2)
			

		end
	end
end

function sm:update()
	for _, eid in world:each "state_chain" do
		local e = world[eid]
		local state_chain = e.state_chain
		local ani = assert(e.animation)

		local srcstate = state_chain.current
		local chain = state_chain.chain

		if state_chain.transmit then
			if state_chain.transmit() then
				state_chain.transmit = nil
			end
		elseif state_chain.dest then
			local dststate = state_chain.dest
			assert(get_pose(chain, srcstate), string.format("invalid state:%s", srcstate))
			assert(get_pose(chain, dststate), string.format("invalid state:%s", dststate))			

			local transmits = state_chain.transmits
			local transmit = transmits[srcstate]

			local dst_trantype = transmit.dst_translist[dststate]
			if dst_trantype == nil then
				error(string.format("dest state:%s, not reachable!", dststate))
			end

			local srcinput = {
				transtype = transmit.src_transtype,
				pose = get_pose(chain, srcstate)
			}
			local dstinput = {
				transtype = dst_trantype,
				pose = get_pose(chain, dststate)
			}

			local op = get_transimit(state_chain.script)

			state_chain.transmit = function (deltatime)
				return op(srcinput, dstinput, ani, transmit.time, deltatime)
			end

			state_chain.dest = nil
		end
	end
end


local smtest = ecs.system "state_machine_test"
smtest.dependby "state_machine_test"

function smtest:init()

end