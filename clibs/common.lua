local lm = require "luamake"
lm.c = "c11"
lm.cxx = "c++20"
lm.msvc = {
    defines = "_CRT_SECURE_NO_WARNINGS",
    flags = {
        "-wd5105"
    }
}

Ant3rd = "../../3rd/"
BgfxInclude = {
    Ant3rd .. "bgfx/include",
    Ant3rd .. "bx/include",
}
LuaInclude = {
    "../lua",
}
