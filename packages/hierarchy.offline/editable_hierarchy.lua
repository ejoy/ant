local ecs = ...
local world = ecs.world

local hierarchy = require "hierarchy"
local assetmgr = import_package "ant.asset"

local fs = require "filesystem"

local eh = ecs.component "editable_hierarchy"{
	ref_path = ""
}

-- TODO
-- save = function (v, arg)
--     assert(type(v) == "string")
--     return v
-- end,
-- load = function (v, arg)
--     assert(type(v) == "string")
--     assert(fs.path(v):extension() == fs.path ".hierarchy")
--     local e = world[arg.eid]
--     e.editable_hierarchy.root = assetmgr.load(v, {editable=true})
--     return v
-- end

function eh:init()
	self.root = hierarchy.new()
end
