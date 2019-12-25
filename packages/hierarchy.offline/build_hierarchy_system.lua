--luacheck: ignore self

local ecs = ...
local world = ecs.world

local util = require "util"

local build_system = ecs.system "build_hierarchy_system"
function build_system:init()
	for _, eid in world:each("editable_hierarchy") do
		util.rebuild_hierarchy(world, eid)
	end
end