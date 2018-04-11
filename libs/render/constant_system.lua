local ecs = ...

local mu = require "math.util"

local constant = ecs.component "constant" {    
}

function constant:init()
    self.colors = {}
end

local constant_init_sys = ecs.system "constant_init_sys"
constant_init_sys.singleton "math_stack"
constant_init_sys.singleton "constant"

function constant_init_sys:init()
    local ms = self.math_stack
    local colors = self.constant.colors

    colors["red"] = mu.create_persistent_vector(ms, {1, 0, 0, 1})
    colors["green"] = mu.create_persistent_vector(ms, {0, 1, 0, 1})
    colors["blue"] = mu.create_persistent_vector(ms, {0, 0, 1, 1})
    colors["black"] = mu.create_persistent_vector(ms, {0, 0, 0, 1})
    colors["white"] = mu.create_persistent_vector(ms, {1, 1, 1, 1})
    colors["yellow"] = mu.create_persistent_vector(ms, {1, 1, 0, 1})
    colors["gray"] = mu.create_persistent_vector(ms, {0.5, 0.5, 0.5, 1})
end