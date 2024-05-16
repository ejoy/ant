local lm = require "luamake"
local fs = require "bee.filesystem"
local platform = require "bee.platform"

local Backlist <const> = {
    window = platform.os == "android",
    debugger = lm.luaversion == "lua55",
}

local Modules = {}

local function checkAddModule(name, makefile)
    if not Backlist[name] then
        lm:import(makefile)
    end
    if lm:has(name) then
        Modules[#Modules + 1] = name
    end
end

for path in fs.pairs(lm.AntDir .. "/clibs") do
    if fs.exists(path / "make.lua") then
        local name = path:stem():string()
        local makefile = ("../clibs/%s/make.lua"):format(name)
        checkAddModule(name, makefile)
    end
end

for path in fs.pairs(lm.AntDir .. "/pkg") do
    if fs.exists(path / "make.lua") then
        local name = path:filename():string()
        local makefile = ("../pkg/%s/make.lua"):format(name)
        checkAddModule(name:sub(5, -1), makefile)
    end
end

lm:copy "copy_mainlua" {
    inputs = "common/main.lua",
    outputs = "$bin/main.lua",
}

lm:lua_src "ant_common" {
    deps = "lua_source",
    includes = {
        lm.AntDir .. "/3rd/bgfx/include",
        lm.AntDir .. "/3rd/bx/include",
        lm.AntDir .. "/3rd/bee.lua",
        "common"
    },
    sources = "common/runtime.cpp",
    windows = {
        sources = {
            "windows/main.cpp",
            lm.AntDir .. "/3rd/bee.lua/3rd/lua/bee_utf8_main.c",
        }
    },
    linux = {
        sources = "posix/main.cpp",
    },
    macos = {
        sources = "posix/main.cpp",
    },
    ios = {
        sources = {
            "common/ios/main.mm",
            "common/ios/ios_error.mm",
        }
    }
}
lm:lua_src "ant_openlibs" {
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
            "IOSurface",
            "CoreGraphics"
        },
        ldflags = {
            "-fembed-bitcode",
            "-fobjc-arc"
        }
    },
    android = {
        links = {
            "android",
            "log",
            "m",
        }
    }
}

local ant_defines = {}

if lm.mode == "debug" then
    ant_defines[#ant_defines+1] = "MATH3D_ADAPTER_TEST"
end

lm:lua_src "ant_runtime" {
    deps = {
        "ant_common",
        Modules,
    },
    includes = {
        "../3rd/bgfx/include",
        "../3rd/bx/include",
    },
    defines = ant_defines,
    sources = "common/modules.c",
}

if lm.os == "android" then
    lm:dll "ant" {
        deps = {
            "ant_runtime",
            "ant_openlibs",
            "bgfx-lib",
            "ant_links",
            "copy_mainlua"
        }
    }
    return
end

lm:exe "ant" {
    deps = {
        "ant_runtime",
        "ant_openlibs",
        "bgfx-lib",
        "ant_links",
        "copy_mainlua"
    },
    windows = {
        sources = "windows/lua.rc",
    },
}
