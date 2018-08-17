local ecs = ...
local primitive_filter = ecs.component "primitive_filter"{

}

function primitive_filter:init()
    self.result = {}
end

local select_filter_comp = ecs.component "select_filter" {

}

function select_filter_comp:init()
    self.result = {}
end





