local ecs = ...
local primitive_filter = ecs.component "primitive_filter"{

}

function primitive_filter:init()
    self.result = {}
end

local lighting_primitive_fiter = ecs.component "lighting_primitive_fiter" {

}

function lighting_primitive_fiter:init()
	self.result = {}
	self.lighting = true
end

local select_filter_comp = ecs.component "select_filter" {

}

function select_filter_comp:init()
    self.result = {}
end





