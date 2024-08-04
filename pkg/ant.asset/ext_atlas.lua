local serialize = import_package "ant.serialize"
local assetmgr = import_package "ant.asset"
local ltask = require "ltask"
local ServiceResource = ltask.queryservice "ant.resource_manager|resource"

local atlas_file = {}

function atlas_file.loader(filename)
	local atlas = serialize.load(filename)
	local rect = atlas.atlas
	local t = assetmgr.load_texture_from_service(ServiceResource, atlas.texture)
	local p = t.texinfo.atlas
	if p then
		rect.x = p.x + rect.x
		rect.y = p.y + rect.y
	end
	t.texinfo.atlas = rect
	return t
end

return atlas_file
