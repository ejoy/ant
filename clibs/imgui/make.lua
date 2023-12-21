local lm = require "luamake"

dofile "../common.lua"

local defines = {
    "IMGUI_DISABLE_OBSOLETE_FUNCTIONS",
    "IMGUI_DISABLE_OBSOLETE_KEYIO",
    "IMGUI_DISABLE_DEBUG_TOOLS",
    "IMGUI_DISABLE_DEMO_WINDOWS",
    "IMGUI_DISABLE_DEFAULT_ALLOCATORS",
    "IMGUI_USER_CONFIG=\\\"imgui_config.h\\\"",
    lm.os == "windows" and "IMGUI_ENABLE_WIN32_DEFAULT_IME_FUNCTIONS"
}

lm:source_set "imgui" {
    includes = {
        ".",
        Ant3rd .. "imgui",
    },
    defines = defines,
    windows = {
        sources = {
            "platform/windows/imgui_platform.cpp",
            Ant3rd .. "imgui/backends/imgui_impl_win32.cpp",
        },
        defines = {
            "_UNICODE",
            "UNICODE",
        }
    },
    macos = {
        --TODO
        deps = "sdl",
        includes = {
            Ant3rd .. "SDL/include",
        },
        sources = {
            "platform/macos/imgui_platform.cpp",
            Ant3rd .. "imgui/backends/imgui_impl_sdl2.cpp",
        },
    },
    ios = {
        sources = {
            "platform/ios/imgui_platform.cpp",
        },
    },
}

lm:source_set "imgui" {
    includes = {
        ".",
        Ant3rd .. "imgui",
    },
    sources = {
        Ant3rd .. "imgui/imgui_draw.cpp",
        Ant3rd .. "imgui/imgui_tables.cpp",
        Ant3rd .. "imgui/imgui_widgets.cpp",
        Ant3rd .. "imgui/imgui.cpp",
    },
    defines = defines,
}

lm:lua_source "imgui" {
    deps = "luabind",
    includes = {
        ".",
        Ant3rd .. "imgui",
        Ant3rd .. "glm",
        Ant3rd .. "bee.lua",
        BgfxInclude,
        "../bgfx",
        "../luabind"
    },
    sources = {
        "imgui_config.cpp",
        "imgui_renderer.cpp",
        "imgui_window.cpp",
        "luaimgui_tables.cpp",
        "luaimgui.cpp",
    },
    defines = {
        "GLM_FORCE_QUAT_DATA_XYZW",
        defines,
    },
    windows = {
        sources = {
            "platform/windows/imgui_font.cpp",
        },
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
        sources = {
            "platform/macos/imgui_osx.mm",
            "platform/macos/imgui_font.mm",
        }
    },
    ios = {
        sources = {
            "platform/macos/imgui_font.mm",
        }
    }
}

lm:runlua "imgui-gen" {
    script = "gen.lua"
}
