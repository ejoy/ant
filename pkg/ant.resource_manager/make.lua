local lm = require "luamake"

lm:lua_src "resource_manager" {
    includes = {
        lm.AntDir .. "/clibs/bgfx",
        lm.AntDir .. "/3rd/bgfx/include",
        lm.AntDir .. "/3rd/bx/include",
    },
    sources = {
        "src/textureman.c",
        "src/programan.c",
    }
}
