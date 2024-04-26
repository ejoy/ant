local lm = require "luamake"


lm:lua_src "image" {
    deps = {
        "bimg-decode",
        "bimg",
        "bx",
    },
    confs = { "glm", "bgfx" },
    includes = {
        lm.AntDir .. "/3rd/bimg/include",
        lm.AntDir .. "/3rd/bee.lua",
        "../bgfx",
        "../luabind",
    },
    sources = {
        "image.cpp",
    },
}
