local require = import and import(...) or require

local hierarchy_module = require "hierarchy"
local vfs = require "vfs"

return function(filename, param)
	local realfilename = vfs.realpath(filename)
	if param and param.editable then
		local editable_hie = hierarchy_module.new()
		hierarchy_module.load(editable_hie, realfilename)
		return editable_hie
	end

	return hierarchy_module.build(realfilename)
end