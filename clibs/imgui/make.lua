local lm = require "luamake"

dofile "../common.lua"
lm:import "../luabind/build.lua"

local defines = {
    "IMGUI_DISABLE_OBSOLETE_FUNCTIONS",
    "IMGUI_DISABLE_OBSOLETE_KEYIO",
    "IMGUI_DISABLE_METRICS_WINDOW",
    "IMGUI_DISABLE_DEMO_WINDOWS",
    "IMGUI_DISABLE_DEFAULT_ALLOCATORS",
    "IMGUI_USER_CONFIG=\\\"imgui_config.h\\\"",
    lm.os == "windows" and "IMGUI_ENABLE_WIN32_DEFAULT_IME_FUNCTIONS"
}

lm:source_set "source_imgui" {
    includes = {
        ".",
        Ant3rd .. "imgui",
        Ant3rd .. "SDL/include",
    },
    sources = {
        Ant3rd .. "imgui/imgui_draw.cpp",
        Ant3rd .. "imgui/imgui_tables.cpp",
        Ant3rd .. "imgui/imgui_widgets.cpp",
        Ant3rd .. "imgui/imgui.cpp",
        Ant3rd .. "imgui/backends/imgui_impl_sdl.cpp",
    },
    defines = defines,
}

lm:source_set "source_imgui" {
    includes = {
        ".",
        Ant3rd .. "imgui",
    },
    sources = {
        "widgets/*.cpp",
    },
    defines = defines,
}

lm:source_set "source_imgui" {
    deps = {
        "sdl",
        "luabind"
    },
    includes = {
        ".",
        Ant3rd .. "imgui",
        Ant3rd .. "glm",
        Ant3rd .. "SDL/include",
        BgfxInclude,
        LuaInclude,
        "../bgfx",
        "../luabind"
    },
    sources = {
        "imgui_config.cpp",
        "imgui_renderer.cpp",
        "imgui_platform.cpp",
        "imgui_window.cpp",
        "luaimgui_tables.cpp",
        "luaimgui.cpp",
    },
    defines = {
        "GLM_FORCE_QUAT_DATA_XYZW",
        defines,
    },
    windows = {
        links = {
            "user32",
            "shell32",
            "ole32",
            "imm32",
            "dwmapi",
            "gdi32",
            "uuid"
        },
    },
    macos = {
        sources = "platform/imgui_osx.mm",
    }
}

lm:lua_dll "imgui" {
    deps = "source_imgui"
}
