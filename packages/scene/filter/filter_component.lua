local ecs = ...
local primitive_filter = ecs.component_struct "primitive_filter"{

}

function primitive_filter:init()
	self.result = {}
end