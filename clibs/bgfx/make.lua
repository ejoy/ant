local lm = require "luamake"

lm:import "bgfx.lua"

lm:lua_src "bgfx" {
    confs = { "bgfx" },
    deps = {
        "bx",
        "copy_bgfx_shader",
    },
    includes = {
        lm.AntDir.."/3rd/bee.lua/3rd/lua-seri"
    },
    sources = {
        "*.c",
        "*.cpp"
    },
    msvc = {
        flags = {
            "-wd4244",
            "-wd4267",
        }
    },
}
