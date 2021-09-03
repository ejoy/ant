local lm = require "luamake"
local fs = require "bee.filesystem"

local Backlist = {
    filedialog = true,
    filewatch = true,
    imgui = true,
    subprocess = true,
    bake = true,
    bake2 = true,
}

local RuntimeModules = {}

for path in (fs.path(lm.workdir) / "../clibs"):list_directory() do
    if fs.exists(path / "make.lua") then
        local name = path:stem():string()
        if not Backlist[name] then
            lm:import(("../clibs/%s/make.lua"):format(name))
            RuntimeModules[#RuntimeModules + 1] = "source_" .. name
        end
    end
end

lm:source_set "ant_common" {
    includes = {
        "../clibs/lua",
        "../3rd/bgfx/include",
        "../3rd/bx/include",
    },
    sources = {
        "common/modules.cpp",
        "common/runtime.cpp",
    },
    windows = {
        sources = "common/set_current_win32.cpp"
    },
    macos = {
        sources = "common/set_current_osx.cpp"
    },
    ios = {
        sources = "common/set_current_ios.mm"
    }
}

lm:lib "ant_runtime" {
    rootdir = "common",
    deps = {
        "ant_common",
        RuntimeModules
    },
    includes = {
        "../../clibs/lua",
        "."
    },
    windows = {
        sources = "../windows/main.cpp",
    },
    macos = {
        sources = "../osx/main.cpp",
    },
    ios = {
        includes = "../../clibs/window/ios",
        sources = {
            "ios/main.mm",
            "ios/ios_error.mm",
        },
    }
}

lm:source_set "ant_links" {
    windows = {
        links = {
            "shlwapi",
        }
    },
    macos = {
        frameworks = {
            "Foundation",
            "Metal",
            "QuartzCore",
            "Cocoa"
        }
    },
    ios = {
        frameworks = {
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

lm:source_set "ant_openlibs" {
    includes = "../clibs/lua",
    sources = "common/ant_openlibs.c",
}

lm:exe "ant" {
    deps = {
        "bgfx-lib",
        "ant_runtime",
        "ant_openlibs",
        "ant_links",
    },
}

lm:default "ant"
