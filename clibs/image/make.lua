local lm = require "luamake"

dofile "../common.lua"

lm:lua_source "image" {
    deps = {
        "bimg-decode",
        "bimg",
        "bx",
    },
    defines = {
        "BX_CONFIG_DEBUG=" .. (lm.mode == "debug" and 1 or 0),
        "GLM_FORCE_QUAT_DATA_XYZW",
        "GLM_ENABLE_EXPERIMENTAL",
    },
    includes = {
        BgfxInclude,
        lm.AntDir .. "/3rd/bimg/include",
        lm.AntDir .. "/3rd/glm",
        lm.AntDir .. "/3rd/bee.lua",
        "../bgfx",
        "../luabind",
    },
    sources = {
        "image.cpp",
    },
}
