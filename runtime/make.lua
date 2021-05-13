local lm = require "luamake"
local fs = require "bee.filesystem"

local Backlist = {
    filedialog = true,
    filewatch = true,
    imgui = true,
    subprocess = true,
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
        "common/searcher.cpp",
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
        ldflags = {
            "-framework", "Foundation",
            "-framework", "Metal",
            "-framework", "QuartzCore",
            "-framework", "Cocoa"
        }
    },
    ios = {
        includes = "../clibs/window/ios",
        sources = {
            "ios/ant/main.mm",
            "ios/ant/ios_error.mm",
        },
        ldflags = {
            "-framework", "CoreText",
            "-framework", "UIKit",
            "-framework", "Metal",
            "-framework", "QuartzCore",
            "-framework", "OpenGLES",
            "-isysroot", "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk",
            "-fembed-bitcode",
            "-fobjc-arc"
        },
        flags = {
            "-isysroot", "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk",
            "-fembed-bitcode",
            "-fobjc-arc"
        }
    }
}

lm:default "ant"
