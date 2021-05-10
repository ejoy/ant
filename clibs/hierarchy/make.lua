local lm = require "luamake"

dofile "../common.lua"

local LIB_SUFFIX = lm.mode == "release" and "_r" or "_d"
local OzzDir = Ant3rd..lm.builddir.."/ozz-animation/"..lm.mode.."/src/"

lm:source_set "source_hierarchy" {
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
    linkdirs = {
        OzzDir .. "base",
        OzzDir .. "animation/runtime",
        OzzDir .. "animation/offline",
        OzzDir .. "geometry/runtime",
    },
    links = {
        "ozz_geometry" .. LIB_SUFFIX,
        "ozz_animation_offline" .. LIB_SUFFIX,
        "ozz_animation" .. LIB_SUFFIX,
        "ozz_base" .. LIB_SUFFIX,
    }
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
