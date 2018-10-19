local ecs = ...
local primitive_filter = ecs.component "primitive_filter"{

}

function primitive_filter:init()
	self.result = {}
end