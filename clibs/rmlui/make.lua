local lm = require "luamake"

dofile "../common.lua"

lm:import "../font/make.lua"
lm:import "../luabind/build.lua"

--lm.warnings = "error"

lm:source_set "yoga" {
    rootdir = Ant3rd .. "yoga",
    includes = {
        ".",
    },
    defines = lm.mode == "debug" and "DEBUG",
    sources = {
        "yoga/**/*.cpp",
    }
}

lm:source_set "stylecache" {
    rootdir = Ant3rd .. "stylecache",
    includes = {
        ".",
    },
    sources = {
        "*.c",
    }
}

lm:source_set "rmlui_core" {
    includes = {
        ".",
        Ant3rd .. "glm",
        Ant3rd .. "yoga",
        Ant3rd .. "stylecache",
    },
    defines = {
        "GLM_FORCE_QUAT_DATA_XYZW",
        lm.mode == "debug" and "DEBUG",
    },
    sources = {
        "core/*.cpp",
    }
}

lm:source_set "rmlui_databinding" {
    includes = {
        ".",
        Ant3rd .. "glm",
        Ant3rd .. "yoga",
    },
    defines = "GLM_FORCE_QUAT_DATA_XYZW",
    sources = {
        "databinding/*.cpp",
    }
}

lm:lua_source "rmlui_binding" {
    includes = {
        ".",
        Ant3rd .. "bgfx/include",
        Ant3rd .. "bx/include",
        Ant3rd .. "bgfx/3rdparty",
        Ant3rd .. "glm",
        Ant3rd .. "yoga",
        "../luabind",
    },
    defines = "GLM_FORCE_QUAT_DATA_XYZW",
    sources = {
        "binding/*.cpp",
    }
}

lm:source_set "rmlui" {
    deps = {
        "yoga",
        "stylecache",
        "luabind",
        "rmlui_core",
        "rmlui_databinding",
        "rmlui_binding",
    },
    windows = {
        links = "user32"
    }
}
