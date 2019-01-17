local ecs = ...
local world = ecs.world

local hierarchy = require "hierarchy"
local assetmgr = import_package "ant.asset"

local fs = require "filesystem"

local eh = ecs.component "editable_hierarchy" {
	ref_path = ""
}

function eh:init()
	self.root = hierarchy.new()
end

function eh:save()
	assert(type(self.ref_path) == "table") -- vfs.path
	self.ref_path = self.ref_path:string()
	return self
end

function eh:load()
	assert(type(self.ref_path) == "string")
	assert(fs.path(self.ref_path):extension() == fs.path ".hierarchy")
	self.root = assetmgr.load(self.ref_path, {editable=true})
	return v
end
