local ecs = ...
local world = ecs.world

local hierarchy_module = require "hierarchy"

local build_system = ecs.system "build_hierarchy_system"

local function build(eid)
	local e = world[eid]
	if e.editable_hierarchy then
		if e.hierarchy == nil then
			world:add_component(eid, "hierarchy")
		end

		local root = assert(e.editable_hierarchy.root)
		e.hierarchy.builddata = assert(hierarchy_module.build(root))

		world:change_component(eid, "hierarchy_changed")

		local hie_np = e.hierarchy_name_mapper
		if hie_np then
			local namemapper = hie_np.v		
			for _, ceid in pairs(namemapper) do
				build(ceid)
			end
		end
	end
end

function build_system:init()
	for _, eid in world:each("editable_hierarchy") do
		build(eid)		
	end
	world:notify()
end

function build_system.notify:rebuild_hierarchy(set)
	for _, eid in ipairs(set) do
		build(eid)		
	end
	world:notify()
end