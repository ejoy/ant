local lm = require "luamake"

dofile "../common.lua"

lm:import "../font/make.lua"

lm:source_set "yoga" {
    rootdir = Ant3rd .. "yoga",
    includes = {
        ".",
    },
    sources = {
        "yoga/*.cpp",
    }
}

lm:source_set "rmlui_core" {
    rootdir = Ant3rd .. "rmlui",
    includes = {
        "Include",
        Ant3rd .. "glm",
        Ant3rd .. "yoga",
    },
    sources = {
        "Source/*.cpp",
    }
}

lm:source_set "source_rmlui" {
    deps = {
        "yoga",
        "rmlui_core",
    },
    includes = {
        LuaInclude,
        BgfxInclude,
        Ant3rd .. "glm",
        Ant3rd .. "rmlui/Include",
        Ant3rd .. "bgfx/3rdparty",
    },
    sources = {
        "*.cpp",
    },
    windows = {
        links = "user32"
    }
}

lm:lua_dll "rmlui" {
    deps = {
        "yoga",
        "rmlui_core",
        "font",
    },
    includes = {
        LuaInclude,
        BgfxInclude,
        Ant3rd .. "glm",
        Ant3rd .. "rmlui/Include",
        Ant3rd .. "bgfx/3rdparty",
    },
    defines = {
        "FONT_EXPORT"
    },
    sources = {
        "*.cpp",
    },
    windows = {
        links = "user32"
    }
}
