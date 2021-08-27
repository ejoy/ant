local lm = require "luamake"

lm:import "scripts/bgfx.lua"
lm:import "scripts/ozz-animation.lua"
lm:import "scripts/reactphysics3d.lua"

lm:phony "3rd_init" {
    deps = {
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

lm:phony "3rd_clean" {
    deps = {
        "ozz-animation_clean",
        "reactphysics3d_clean",
    }
}

lm:phony "3rd"{
    deps = {
        "3rd_init",
        "3rd_make"
    }
}

lm:default "3rd_make"
