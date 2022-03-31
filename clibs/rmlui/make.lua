local lm = require "luamake"

dofile "../common.lua"

lm:import "../font/make.lua"
lm:import "../luabind/build.lua"

lm.warnings = "error"

lm:source_set "yoga" {
    rootdir = Ant3rd .. "yoga",
    includes = {
        ".",
    },
    sources = {
        "yoga/**.cpp",
    }
}

lm:source_set "rmlui_core" {
    includes = {
        ".",
        Ant3rd .. "glm",
        Ant3rd .. "yoga",
    },
    defines = "GLM_FORCE_QUAT_DATA_XYZW",
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

lm:source_set "rmlui_binding" {
    includes = {
        ".",
        LuaInclude,
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

lm:source_set "source_rmlui" {
    deps = {
        "yoga",
        "luabind",
        "rmlui_core",
        "rmlui_databinding",
        "rmlui_binding",
    },
    windows = {
        links = "user32"
    }
}

lm:lua_dll "rmlui" {
    deps = {
        "source_rmlui",
    }
}
