local require = import and import(...) or require

local hierarchy_module = require "hierarchy"
local vfs = require "vfs"
local assetmgr = require "asset"

return function(filename, param)
	local fn = assetmgr.find_valid_asset_path(filename)
	if fn == nil then
		error(string.format("invalid file in ext_hierarchy, %s", filename))
	end

	local realfilename = vfs.realpath(fn)
	if param and param.editable then
		local editable_hie = hierarchy_module.new()
		hierarchy_module.load(editable_hie, realfilename)
		return editable_hie
	end

	return hierarchy_module.build(realfilename)
end