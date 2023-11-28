local lm = require "luamake"

dofile "../common.lua"

lm:lua_source "hierarchy" {
    deps = {
        "ozz-animation-base",
        "ozz-animation-runtime",
        "ozz-animation-offline",
        "ozz-animation-geometry",
        "bx",
    },
    includes = {
        BgfxInclude,
        Ant3rd .. "ozz-animation/include",
        Ant3rd .. "glm",
        Ant3rd .. "bee.lua",
    },
    sources = {
        "hierarchy.cpp",
        "hierarchy_node.cpp",
        "animation.cpp",
        "ik.cpp",
        Ant3rd .. "ozz-animation/samples/framework/mesh.cc"
    },
    defines = {
        "GLM_FORCE_QUAT_DATA_XYZW",
        "BX_CONFIG_DEBUG=" .. (lm.mode == "debug" and 1 or 0),
    },
}
