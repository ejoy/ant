local lm = require "luamake"

lm:source_set "efk" {
    includes = {
        lm.AntDir .. "/3rd/Effekseer/Dev/Cpp/Effekseer",
        lm.AntDir .. "/3rd/Effekseer/Dev/Cpp/EffekseerRendererCommon",
        lm.AntDir .. "/3rd/bgfx/include",
        lm.AntDir .. "/3rd/bx/include",
    },
    sources = {
        "efkbgfx/renderer/bgfxrenderer.cpp",
        lm.AntDir .. "/3rd/Effekseer/Dev/Cpp/Effekseer/Effekseer/**/*.cpp",
        lm.AntDir .. "/3rd/Effekseer/Dev/Cpp/EffekseerMaterial/*.cpp",
        lm.AntDir .. "/3rd/Effekseer/Dev/Cpp/EffekseerRendererCommon/**/*.cpp",
    },
    defines = {
        "BX_CONFIG_DEBUG=" .. (lm.mode == "debug" and 1 or 0),
    },
    gcc = {
        flags = {
            "-Wno-sign-compare",
            "-Wno-unused-but-set-variable",
            "-Wno-format",
            "-Wno-unused-variable",
        }
    },
    clang = {
        flags = {
            "-Wno-delete-non-abstract-non-virtual-dtor",
            "-Wno-unused-but-set-variable",
            "-Wno-unused-variable",
            "-Wno-inconsistent-missing-override",
        }
    }
}

lm:lua_source "efk" {
    sources = {
        "efkbgfx/luabinding/efkcallback.c",
    }
}

lm:lua_source "efk" {
    includes = {
        lm.AntDir .. "/3rd/Effekseer/Dev/Cpp/Effekseer",
        lm.AntDir .. "/3rd/Effekseer/Dev/Cpp/EffekseerRendererCommon",
        lm.AntDir .. "/3rd/bgfx/include",
        lm.AntDir .. "/3rd/bx/include",
        lm.AntDir .. "/3rd/bee.lua",
        lm.AntDir .. "/clibs/luabind",
        lm.AntDir .. "/pkg/ant.resource_manager/src",
    },
    sources = {
        "lefk.cpp",
    }
}
