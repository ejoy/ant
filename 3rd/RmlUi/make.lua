local lm = require "luamake"

lm.mode = "debug"
lm.arch = "x64"

lm.bindir = "../build/RmlUi/msvc/"..lm.mode.."/"..lm.mode

lm:lib "RmlCore" {
    defines = {
        "RMLUI_STATIC_LIB",
        "RMLUI_NO_FONT_INTERFACE_DEFAULT",
    },
    includes = {
        "Include",
    },
    sources = {
        "Source/Core/*.cpp",
        "!Source/Core/FontEngineDefault/*"
    },
    flags = {
        "/wd4819"
    },
    links = {
        "opengl32",
        "user32",
        "gdi32",
        "shlwapi",
    },
}

lm:lib "RmlDebugger" {
    defines = {
        "RMLUI_STATIC_LIB",
    },
    includes = {
        "Include",
    },
    sources = {
        "Source/Debugger/*.cpp",
    },
    flags = {
        "/wd4819"
    },
}

lm:lib "yoga" {
    rootdir = "../yoga",
    includes = {
        ".",
    },
    sources = {
        "yoga/*.cpp",
    }
}
