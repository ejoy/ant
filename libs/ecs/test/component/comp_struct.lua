local ecs = ...

local compstruct = ecs.component_struct "c_struct"
-- using new function will lost save&load function for serializing
function compstruct.new()
	return ""
end