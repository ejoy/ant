local ecs = ...

local render_filter = ecs.component "render_filter" {    

}

function render_filter:init()
    self.result = {}
end

local primitive_filter = ecs.component "primitive_filter"{

}

function primitive_filter:init()
    self.result = {}
end





