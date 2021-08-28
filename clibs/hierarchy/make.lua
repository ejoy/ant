local lm = require "luamake"

dofile "../common.lua"

lm:source_set "source_hierarchy" {
    deps = {
        "ozz-animation-base",
        "ozz-animation-runtime",
        "ozz-animation-geometry",
    },
    includes = {
        LuaInclude,
        Ant3rd .. "ozz-animation/include",
        Ant3rd .. "glm",
    },
    sources = {
        "hierarchy.cpp",
        "animation.cpp",
        "ik.cpp",
        "ozzmesh.cpp",
        "scene.c",
        Ant3rd .. "ozz-animation/samples/framework/mesh.cc"
    },
    defines = {
        "GLM_FORCE_QUAT_DATA_XYZW",
    },
}

lm:lua_dll "hierarchy" {
    deps = "source_hierarchy",
    msvc = {
        ldflags = {
            "-export:luaopen_hierarchy_scene",
            "-export:luaopen_hierarchy_animation"
        }
    }
}
