local lm = require "luamake"
local fs = require "bee.filesystem"
fs.create_directories(fs.path(("build/%s/bin"):format(lm.plat)))

lm:import "scripts/bgfx.lua"
lm:import "scripts/ozz-animation.lua"
lm:import "scripts/reactphysics3d.lua"

lm:phony "3rd_init" {
    deps = {
        "bgfx_init",
        "ozz-animation_init",
        "reactphysics3d_init",
    }
}

lm:phony "3rd_make" {
    deps = {
        "bgfx_make",
        "ozz-animation_make",
        "reactphysics3d_make",
    }
}

lm:default {
    "3rd_make"
}
