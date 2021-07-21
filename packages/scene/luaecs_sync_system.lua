local ecs = ...
local world = ecs.world

local s = ecs.system "luaecs_sync_system"

local evCreate = world:sub {"component_register", "scene_entity"}

function s:update_hierarchy()
	for _, _, eid in evCreate:unpack() do
		world:pub {"luaecs", "create_entity", eid}
	end
	for _, eid in world:each "removed" do
		local e = world[eid]
		if e.scene_entity then
			world:pub {"luaecs", "remove_entity", eid}
		end
	end
end
