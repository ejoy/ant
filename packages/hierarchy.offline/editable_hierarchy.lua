local ecs = ...
local world = ecs.world
local schema = world.schema

local hierarchy = require "hierarchy"
local assetmgr = import_package "ant.asset"

schema:type "editable_hierarchy"
	.ref_path "resource"

local eh = ecs.component "editable_hierarchy"

function eh:init()
	self.root = hierarchy.new()
	return self
end

function eh:load()
	self.root = assetmgr.load(self.ref_path.package, self.ref_path.filename, {editable=true})
	return self
end
