local lm = require "luamake"
local fs = require "bee.filesystem"

local runtime = false

local RuntimeBacklist = {
    filedialog = true,
    filewatch = true,
    imgui = true,
    subprocess = true,
    bake = true,
}

local EditorBacklist = {
    firmware = true,
    bake = true,
    audio = (lm.os == "windows" and lm.compiler == "gcc")
}

local RuntimeModules = {}
local EditorModules = {}

for path in fs.pairs(fs.path(lm.workdir) / "../clibs") do
    if fs.exists(path / "make.lua") then
        local name = path:stem():string()
        if not RuntimeBacklist[name] or not EditorBacklist[name] then
            lm:import(("../clibs/%s/make.lua"):format(name))
        end
        if not RuntimeBacklist[name] then
            RuntimeModules[#RuntimeModules + 1] = "source_" .. name
        end
        if not EditorBacklist[name] then
            EditorModules[#EditorModules + 1] = "source_" .. name
        end
    end
end

lm:copy "copy_mainlua" {
    input = "common/main.lua",
    output = "../"..lm.bindir,
}

lm:source_set "ant_common" {
    includes = {
        "../clibs/lua",
        "../3rd/bgfx/include",
        "../3rd/bx/include",
    },
    sources = {
        "common/runtime.cpp",
        "common/progdir.cpp",
    },
    windows = {
        includes = {
            "../clibs/lua",
            "common"
        },
        sources = "windows/main.cpp",
    },
    macos = {
        sources = "../osx/main.cpp",
    },
    ios = {
        includes = "../../clibs/window/ios",
        sources = {
            "ios/main.mm",
            "ios/ios_error.mm",
        }
    }
}

lm:source_set "ant_openlibs" {
    includes = "../clibs/lua",
    sources = "common/ant_openlibs.c",
}

lm:source_set "ant_links" {
    windows = {
        links = {
            "shlwapi",
            "user32",
            "gdi32",
            "shell32",
            "ole32",
            "oleaut32",
            "wbemuuid",
            "winmm",
            "ws2_32",
            "imm32",
            "advapi32",
            "version",
        }
    },
    macos = {
        frameworks = {
            "Carbon",
            "IOKit",
            "Foundation",
            "Metal",
            "QuartzCore",
            "Cocoa"
        }
    },
    ios = {
        frameworks = {
            "CoreTelephony",
            "SystemConfiguration",
            "Foundation",
            "CoreText",
            "UIKit",
            "Metal",
            "QuartzCore",
        },
        ldflags = {
            "-fembed-bitcode",
            "-fobjc-arc"
        }
    }
}

lm:source_set "ant_runtime" {
    deps = {
        "ant_common",
        RuntimeModules,
    },
    includes = {
        "../clibs/lua",
        "../3rd/bgfx/include",
        "../3rd/bx/include",
    },
    defines = "ANT_RUNTIME",
    sources = "common/modules.c",
}

lm:source_set "ant_editor" {
    deps = {
        "ant_common",
        EditorModules,
    },
    includes = {
        "../clibs/lua",
        "../3rd/bgfx/include",
        "../3rd/bx/include",
    },
    sources = "common/modules.c",
}

lm:exe "lua" {
    deps = {
        "ant_editor",
        "ant_openlibs",
        "bgfx-lib",
        "ant_links",
        "copy_mainlua"
    }
}

lm:exe "ant" {
    deps = {
        "ant_runtime",
        "ant_openlibs",
        "bgfx-lib",
        "ant_links",
        "copy_mainlua"
    }
}

lm:phony "editor" {
    deps = "lua"
}

lm:phony "runtime" {
    deps = "ant"
}