local lm = require "luamake"

local EnableEditor = lm.os ~= "ios"

lm.warnings = {
    "error",
    "on"
}

lm.cxx = "c++17"

lm.msvc = {
    defines = "_CRT_SECURE_NO_WARNINGS",
    includes = "../bx/include/compat/msvc",
}

lm.mingw = {
    includes = "../bx/include/compat/mingw",
}

lm.macos = {
    includes = "../bx/include/compat/osx",
}

lm.ios = {
    includes = "../bx/include/compat/ios",
    flags = {
        "-fembed-bitcode",
    }
}

require "bgfx.bx"
require "bgfx.bimg"
require "bgfx.bgfx-lib"

if not EnableEditor then
    return
end

require "bgfx.bgfx-dll"
require "bgfx.shaderc"
require "bgfx.texturec"
require "bgfx.texturev"
