local ecs = ...

local math = import_package "ant.math"
local mu = math.util

local constant = ecs.singleton "constant"

function constant:init()
    return {
        colors = {},
        tcolors = {},
    }
end

local constant_init_sys = ecs.system "constant_init_sys"
constant_init_sys.singleton "constant"

--luacheck: ignore self
function constant_init_sys:init()    
    local colors = self.constant.colors

    colors["red"] = mu.create_persistent_vector({1, 0, 0, 1})
    colors["green"] = mu.create_persistent_vector({0, 1, 0, 1})
    colors["blue"] = mu.create_persistent_vector({0, 0, 1, 1})
    colors["black"] = mu.create_persistent_vector({0, 0, 0, 1})
    colors["white"] = mu.create_persistent_vector({1, 1, 1, 1})
    colors["yellow"] = mu.create_persistent_vector({1, 1, 0, 1})
    colors["gray"] = mu.create_persistent_vector({0.5, 0.5, 0.5, 1})

    local tcolors = self.constant.tcolors

    tcolors["red"] = {1, 0, 0, 1}
    tcolors["green"] = {0, 1, 0, 1}
    tcolors["blue"] = {0, 0, 1, 1}
    tcolors["black"] = {0, 0, 0, 1}
    tcolors["white"] = {1, 1, 1, 1}
    tcolors["yellow"] = {1, 1, 0, 1}
    tcolors["gray"] = {0.5, 0.5, 0.5, 1}
end