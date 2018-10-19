local require = import and import(...) or require

local hierarchy_module = require "hierarchy"

return function(filename, param)
	if param and param.editable then
		local editable_hie = hierarchy_module.new()
		hierarchy_module.load(editable_hie, filename)
		return editable_hie
	end

	return hierarchy_module.build(filename)
end