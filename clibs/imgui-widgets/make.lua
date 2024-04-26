local lm = require "luamake"

local defines = {
    "IMGUI_DISABLE_OBSOLETE_FUNCTIONS",
    "IMGUI_DISABLE_OBSOLETE_KEYIO",
    "IMGUI_DISABLE_DEBUG_TOOLS",
    "IMGUI_DISABLE_DEMO_WINDOWS",
    "IMGUI_DISABLE_DEFAULT_ALLOCATORS",
    "IMGUI_USER_CONFIG=\\\"imgui_lua_config.h\\\"",
    lm.os == "windows" and "IMGUI_ENABLE_WIN32_DEFAULT_IME_FUNCTIONS"
}

lm:source_set "imgui" {
    includes = {
        "../imgui",
        lm.AntDir .. "/3rd/imgui",
    },
    confs = { "glm" },
    sources = {
        "zmo/*.cpp",
        "widgets/*.cpp",
    },
    defines = {
        defines,
    },
}

lm:lua_src "imgui" {
    confs = { "glm" },
    includes = {
        "../imgui",
        lm.AntDir .. "/3rd/imgui",
    },
    sources = {
        "luabinding.cpp",
    },
    defines = {
        defines,
    },
}

lm:source_set "imgui-widgets" {
}
