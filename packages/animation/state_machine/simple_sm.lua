local ecs = ...
local world = ...

local smtest = ecs.system "simple_sm"
smtest.dependby "state_machine"

function smtest:init()
	local char = world:first_entity("character")
	local states = char.state_chain
	if states then
		local chain = states.chain

		chain[#chain+1] = {
			name = "idle",
			pose = {
				name = "idle",
				anilist = {
					{idx=1, weight=0.5},
					{idx=2, weight=0.5},
				},
			}
		}

		chain[#chain+1] = {
			name = "walk",
			pose = {
				name = "walk",
				anilist = {
					{idx=3, weight=1},
				}
			}
		}

		local transmits = states.transmits
		transmits["idle"] = {
			{duration = 0.5, targetname="walk"},
		}

		transmits["walk"] = {
			{duration = 0.3, targetname="idle"}
		}
	end
end