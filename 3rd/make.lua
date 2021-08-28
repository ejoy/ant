local lm = require "luamake"

lm:import "scripts/bgfx.lua"
lm:import "scripts/ozz-animation.lua"
lm:import "scripts/reactphysics3d.lua"

lm:phony "3rd" {
    deps = {
        "bgfx_make",
        "ozz-animation_make",
        "reactphysics3d_make",
    }
}
