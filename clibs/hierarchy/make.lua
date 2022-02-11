local lm = require "luamake"

dofile "../common.lua"

lm:source_set "source_hierarchy" {
    deps = {
        "ozz-animation-base",
        "ozz-animation-runtime",
        "ozz-animation-offline",
        "ozz-animation-geometry",
        "bx"
    },
    includes = {
        LuaInclude,
        BgfxInclude,
        Ant3rd .. "ozz-animation/include",
        Ant3rd .. "glm",
    },
    sources = {
        "hierarchy.cpp",
        "animation.cpp",
        "ik.cpp",
        Ant3rd .. "ozz-animation/samples/framework/mesh.cc"
    },
    defines = {
        "GLM_FORCE_QUAT_DATA_XYZW",
        lm.mode == "debug" and "BX_CONFIG_DEBUG=1",
    },
}

lm:lua_dll "hierarchy" {
    deps = "source_hierarchy",
}
