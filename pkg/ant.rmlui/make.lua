local lm = require "luamake"

local ROOT <const> = "../../"

--lm.warnings = "error"

lm:source_set "yoga" {
    rootdir = ROOT .. "3rd/yoga",
    includes = ".",
    defines = lm.mode == "debug" and "DEBUG",
    sources = "yoga/**/*.cpp",
    android = {
        defines = "ANDROID"
    }
}

lm:source_set "stylecache" {
    rootdir = ROOT .. "3rd/stylecache",
    includes = ".",
    sources = {
        "*.c",
        "!test*.c",
    }
}

lm:lua_source "rmlui_core" {
    includes = {
        "src",
        ROOT .. "3rd/glm",
        ROOT .. "3rd/yoga",
        ROOT .. "3rd/bee.lua",
        ROOT .. "clibs/luabind",
    },
    defines = {
        "GLM_FORCE_QUAT_DATA_XYZW",
        lm.mode == "debug" and "DEBUG",
    },
    sources = {
        "src/core/*.cpp",
        "src/util/*.cpp",
    }
}

lm:lua_source "rmlui_css" {
    includes = {
        "src",
        ROOT .. "3rd/glm",
        ROOT .. "3rd/stylecache",
        ROOT .. "3rd/bee.lua",
        ROOT .. "clibs/luabind",
    },
    defines = {
        "GLM_FORCE_QUAT_DATA_XYZW",
        lm.mode == "debug" and "DEBUG",
    },
    sources = {
        "src/css/*.cpp",
    }
}

lm:lua_source "rmlui_binding" {
    includes = {
        "src",
        ROOT .. "3rd/bgfx/include",
        ROOT .. "3rd/bx/include",
        ROOT .. "3rd/bgfx/3rdparty",
        ROOT .. "3rd/glm",
        ROOT .. "3rd/yoga",
        ROOT .. "3rd/bee.lua",
        ROOT .. "clibs/luabind",
        ROOT .. "pkg/ant.resource_manager/src/",
        ROOT .. "pkg/ant.font/src/",
    },
    defines = "GLM_FORCE_QUAT_DATA_XYZW",
    sources = {
        "src/binding/*.cpp",
    }
}

lm:source_set "rmlui" {
    deps = {
        "yoga",
        "stylecache",
        "luabind",
        "rmlui_core",
        "rmlui_css",
        "rmlui_binding",
    },
    windows = {
        links = "user32"
    }
}
