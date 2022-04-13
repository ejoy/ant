local lm = require "luamake"

lm.cxx = "c++17"

lm.warnings = {
    "error",
    "on"
}

lm.defines = "BX_CONFIG_DEBUG=" .. (lm.mode == "debug" and 1 or 0)

lm.msvc = {
    defines = "_CRT_SECURE_NO_WARNINGS",
    includes = BxDir .. "include/compat/msvc",
}

lm.mingw = {
    includes = BxDir .. "include/compat/mingw",
}

lm.macos = {
    includes = BxDir .. "include/compat/osx",
}

lm.ios = {
    includes = BxDir .. "include/compat/ios",
    flags = {
        "-fembed-bitcode",
        "-Wno-unused-function"
    }
}

lm.clang = {
    flags = {
        "-Wno-tautological-constant-compare",
        "-Wno-unused-but-set-variable",
    }
}

require "bgfx.bx"
require "bgfx.bimg"
require "bgfx.bgfx"

if lm.os == "ios" then
    return
end

if lm.os == "windows" then
    lm:source_set "bgfx-support-utf8" {
        sources = "utf8/utf8.rc"
    }
end

require "bgfx.shaderc"
require "bgfx.texturec"
require "bgfx.texturev"
