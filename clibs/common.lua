local lm = require "luamake"

BgfxInclude = {
    lm.AntDir .. "/3rd/bgfx/include",
    lm.AntDir .. "/3rd/bx/include",
}
if lm.os == "windows" then
    if lm.compiler == "msvc" then
        BgfxInclude[#BgfxInclude+1] = lm.AntDir .. "/3rd/bx/include/compat/msvc"
    else
        BgfxInclude[#BgfxInclude+1] = lm.AntDir .. "/3rd/bx/include/compat/mingw"
    end
end
