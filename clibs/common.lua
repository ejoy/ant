local lm = require "luamake"

Ant3rd = "../../3rd/"
BgfxInclude = {
    Ant3rd .. "bgfx/include",
    Ant3rd .. "bx/include",
}
if lm.os == "windows" then
    if lm.compiler == "msvc" then
        BgfxInclude[#BgfxInclude+1] = Ant3rd .. "bx/include/compat/msvc"
    else
        BgfxInclude[#BgfxInclude+1] = Ant3rd .. "bx/include/compat/mingw"
    end
end

LuaInclude = {
    "../lua",
}

