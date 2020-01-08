--luacheck: ignore self

local ecs = ...
local world = ecs.world

local util = require "util"

local build_system = ecs.system "build_hierarchy_system"
local edit_hierarchy_mb = world:sub {"update_editable_hierarchy"}

function build_system:update_editable_hierarchy()
	for _, eid in edit_hierarchy_mb:unpack() do
		--util.rebuild_hierarchy(world, eid)
	end
end