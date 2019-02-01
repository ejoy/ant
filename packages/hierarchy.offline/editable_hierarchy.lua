local ecs = ...
local world = ecs.world
local schema = world.schema

local fs = require "filesystem"

local hierarchy = require "hierarchy"

schema:typedef("editable_hierarchy", "resource")
local eh = ecs.component "editable_hierarchy"

function eh.init()	
	return {
		ref_path = {package="", filename = fs.path ""},
		assetinfo = {
			handle = hierarchy.new()
		}
	}
end
