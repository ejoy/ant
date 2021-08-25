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

lm:lib "runtime_modules" {
    deps = {
        RuntimeModules
    },
}

lm:exe "ant" {
    deps = {
        "ant_common",
        RuntimeModules
    },
    includes = {
        "../clibs/lua",
        "common"
    },
    links = {
        "bgfx"..lm.mode
    },
    windows = {
        sources = "windows/main.cpp",
        links = {
            "shlwapi",
        }
    },
    macos = {
        sources = "osx/main.cpp",
        frameworks = {
            "Foundation",
            "Metal",
            "QuartzCore",
            "Cocoa"
        }
    },
    ios = {
        deps = "runtime_modules",
        includes = "../clibs/window/ios",
        sources = {
            "ios/ant/main.mm",
            "ios/ant/ios_error.mm",
        },
        frameworks = {
            "CoreText",
            "UIKit",
            "Metal",
            "QuartzCore",
            "OpenGLES",
        },
        ldflags = {
            "-fembed-bitcode",
            "-fobjc-arc"
        },
        flags = {
            "-fembed-bitcode",
            "-fobjc-arc"
        }
    }
}

lm:default "ant"
