local lm = require "luamake"
local fs = require "bee.filesystem"

local runtime = false

local RuntimeBacklist <const> = {
    filedialog = true,
    effekseer = true,
}

local EditorBacklist <const> = {
    firmware = true,
    effekseer = true,
}

local RuntimeAlias <const> = {
    fastio = "fastio_runtime",
}

local EditorAlias <const> = {
    fastio = "fastio_editor",
}

local RuntimeModules = {}
local EditorModules = {}

local function checkAddModule(name, makefile)
    if not RuntimeBacklist[name] or not EditorBacklist[name] then
        lm:import(makefile)
    end
    if not RuntimeBacklist[name] then
        local alias = RuntimeAlias[name] or name
        if lm:has(alias) then
            RuntimeModules[#RuntimeModules + 1] = alias
        end
    end
    if not EditorBacklist[name] then
        local alias = EditorAlias[name] or name
        if lm:has(alias) then
            EditorModules[#EditorModules + 1] = alias
        end
    end
end

for path in fs.pairs(fs.path(lm.workdir) / "../clibs") do
    if fs.exists(path / "make.lua") then
        local name = path:stem():string()
        local makefile = ("../clibs/%s/make.lua"):format(name)
        checkAddModule(name, makefile)
    end
end

for path in fs.pairs(fs.path(lm.workdir) / "../pkg") do
    if fs.exists(path / "make.lua") then
        local name = path:filename():string()
        local makefile = ("../pkg/%s/make.lua"):format(name)
        checkAddModule(name:sub(5, -1), makefile)
    end
end

lm:copy "copy_mainlua" {
    input = "common/main.lua",
    output = "../"..lm.bindir,
}

lm:lua_source "ant_common" {
    deps = "lua_source",
    includes = {
        "../3rd/bgfx/include",
        "../3rd/bx/include",
        "common"
    },
    sources = {
        "common/runtime.cpp",
        "common/progdir.cpp",
    },
    windows = {
        sources = "windows/main.cpp",
    },
    macos = {
        sources = "osx/main.cpp",
    },
    ios = {
        includes = "../../clibs/window/ios",
        sources = {
            "common/ios/main.mm",
            "common/ios/ios_error.mm",
        }
    }
}
lm:lua_source "ant_openlibs" {
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

local antrt_defines = {
    "ANT_RUNTIME",
}

local anted_defines = {}

if lm.mode == "debug" then
    antrt_defines[#antrt_defines+1] = "MATH3D_ADAPTER_TEST"
    anted_defines[#anted_defines+1] = "MATH3D_ADAPTER_TEST"
end

lm:lua_source "ant_runtime" {
    deps = {
        "ant_common",
        RuntimeModules,
    },
    includes = {
        "../3rd/bgfx/include",
        "../3rd/bx/include",
    },
    defines = antrt_defines,
    sources = "common/modules.c",
}

lm:lua_source "ant_editor" {
    deps = {
        "ant_common",
        EditorModules,
    },
    includes = {
        "../3rd/bgfx/include",
        "../3rd/bx/include",
    },
    defines = anted_defines,
    sources = {
        "common/modules.c",
    },
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
    lm:phony "runtime" {
        deps = "ant"
    }
    return
end

lm:exe "lua" {
    deps = {
        "ant_editor",
        "ant_openlibs",
        "bgfx-lib",
        "ant_links",
        "copy_mainlua"
    },
    msvc = {
        sources = "windows/lua.rc",
    },
    mingw = {
        sources = "windows/lua.rc",
    }
}

lm:exe "ant" {
    deps = {
        "ant_runtime",
        "ant_openlibs",
        "bgfx-lib",
        "ant_links",
        "copy_mainlua"
    },
    msvc = {
        sources = "windows/lua.rc",
    },
    mingw = {
        sources = "windows/lua.rc",
    }
}

lm:phony "editor" {
    deps = "lua"
}

lm:phony "runtime" {
    deps = "ant"
}