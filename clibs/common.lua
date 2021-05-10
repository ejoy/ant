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
if lm.os == "windows" then
    if lm.compiler == "msvc" then
        BgfxInclude[#BgfxInclude+1] = Ant3rd .. "bx/include/compat/msvc"
        BgfxLinkdir = Ant3rd .. "bgfx/.build/win64_vs2019/bin"
    else
        BgfxInclude[#BgfxInclude+1] = Ant3rd .. "bx/include/compat/mingw"
        BgfxLinkdir = Ant3rd .. "bgfx/.build/win64_mingw-gcc/bin"
    end
elseif lm.os == "macos" then
    BgfxLinkdir = Ant3rd .. "bgfx/.build/osx-arm64/bin"
else
    BgfxLinkdir = ""
end

LuaInclude = {
    "../lua",
}
