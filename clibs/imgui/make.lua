local lm = require "luamake"

dofile "../common.lua"

lm:source_set "imgui_core" {
    rootdir = Ant3rd .. "imgui",
    includes = {
        ".",
    },
    sources = {
        "imgui_draw.cpp",
        "imgui_tables.cpp",
        "imgui_widgets.cpp",
        "imgui.cpp",
    },
    defines = {
        "IMGUI_DISABLE_OBSOLETE_FUNCTIONS",
        "IMGUI_DISABLE_METRICS_WINDOW",
        "IMGUI_DISABLE_DEMO_WINDOWS",
        "IMGUI_DISABLE_DEFAULT_ALLOCATORS",
    },
    windows = {
        sources = "backends/imgui_impl_win32.cpp"
    }
}

lm:lua_dll "imgui" {
    deps = "imgui_core",
    includes = {
        ".",
        Ant3rd .. "imgui",
        Ant3rd .. "glm",
        BgfxInclude,
        "../bgfx"
    },
    sources = {
        "imgui_config.cpp",
        "imgui_renderer.cpp",
        "imgui_window.cpp",
        "luaimgui_tables.cpp",
        "luaimgui.cpp",
        "widgets/*.cpp"
    },
    defines = {
        "IMGUI_DISABLE_OBSOLETE_FUNCTIONS",
        "IMGUI_DISABLE_METRICS_WINDOW",
        "IMGUI_DISABLE_DEMO_WINDOWS",
        "IMGUI_DISABLE_DEFAULT_ALLOCATORS",
    },
    windows = {
        sources = "win32/*.cpp",
        defines = "UNICODE",
        links = {
            "user32",
            "shell32",
            "ole32",
        },
    },
    mingw = {
        links = {
            "imm32",
            "dwmapi",
            "gdi32",
            "uuid"
        },
    }
}
