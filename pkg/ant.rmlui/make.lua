local lm = require "luamake"

--lm.warnings = "error"
lm.cxx = "c++latest"

lm:source_set "yoga" {
    rootdir = lm.AntDir .. "/3rd/yoga",
    includes = ".",
    defines = lm.mode == "debug" and "DEBUG",
    sources = "yoga/**/*.cpp",
    android = {
        defines = "ANDROID"
    }
}

lm:source_set "stylecache" {
    rootdir = lm.AntDir .. "/3rd/stylecache",
    includes = ".",
    sources = {
        "*.c",
        "!test*.c",
    }
}

lm:lua_src "rmlui_core" {
    confs = { "glm" },
    includes = {
        "src",
        lm.AntDir .. "/3rd/bgfx/include",
        lm.AntDir .. "/3rd/bx/include",
        lm.AntDir .. "/3rd/bgfx/3rdparty",
        lm.AntDir .. "/3rd/yoga",
        lm.AntDir .. "/3rd/bee.lua",
        lm.AntDir .. "/clibs/luabind",
        lm.AntDir .. "/pkg/ant.resource_manager/src/"
    },
    defines = {
        lm.mode == "debug" and "DEBUG",
    },
    sources = {
        "src/core/*.cpp",
        "src/util/*.cpp",
    }
}

lm:lua_src "rmlui_css" {
    confs = { "glm" },
    includes = {
        "src",
        lm.AntDir .. "/3rd/yoga",
        lm.AntDir .. "/3rd/stylecache",
        lm.AntDir .. "/3rd/bee.lua",
    },
    defines = {
        lm.mode == "debug" and "DEBUG",
    },
    sources = {
        "src/css/*.cpp",
    }
}

lm:lua_src "rmlui_binding" {
    confs = { "glm" },
    includes = {
        "src",
        lm.AntDir .. "/3rd/bgfx/include",
        lm.AntDir .. "/3rd/bx/include",
        lm.AntDir .. "/3rd/bgfx/3rdparty",
        lm.AntDir .. "/3rd/yoga",
        lm.AntDir .. "/3rd/bee.lua",
        lm.AntDir .. "/clibs/luabind",
        lm.AntDir .. "/pkg/ant.resource_manager/src/",
        lm.AntDir .. "/pkg/ant.font/src/",
    },
    sources = {
        "src/binding/*.cpp",
    }
}

lm:source_set "rmlui" {
    deps = {
        "yoga",
        "stylecache",
        "rmlui_core",
        "rmlui_css",
        "rmlui_binding",
    },
    windows = {
        links = "user32"
    }
}
