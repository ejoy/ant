local lm = require "luamake"

local function deepcopy(t)
    local r = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            r[k] = deepcopy(v)
        else
            r[k] = v
        end
    end
    local mt = getmetatable(t)
    if mt ~= nil then
        setmetatable(r, mt)
    end
    return r
end

local bgfxLib = {
    rootdir = lm.BgfxDir,
    deps = {
        "bx",
        "bimg"
    },
    defines = {
        "BGFX_CONFIG_MAX_VIEWS=1024",
    },
    includes = {
        lm.BxDir / "include",
        lm.BimgDir / "include",
        "3rdparty",
        "3rdparty/khronos",
        "include",
    },
    sources = {
        "src/*.cpp",
        "!src/amalgamated.cpp",
    },
    msvc = {
        defines = "__STDC_FORMAT_MACROS",
    },
    windows = {
        includes = "3rdparty/dxsdk/include",
    },
    linux = {
        defines = {
            "BGFX_CONFIG_RENDERER_VULKAN=1",
        },
    },
    macos = {
        sources = {
            "src/*.mm",
            "!src/amalgamated.mm",
        },
        flags = {
            "-x", "objective-c++"
        }
    },
    ios = {
        defines = {
            "BGFX_CONFIG_RENDERER_METAL=1",
        },
        sources = {
            "src/*.mm",
            "!src/amalgamated.mm",
        }
    }
}

local bgfxDll = deepcopy(bgfxLib)
table.insert(bgfxDll.defines, "BGFX_SHARED_LIB_BUILD=1")

lm:lib "bgfx-lib" (bgfxLib)
lm:src "bgfx-dll" (bgfxDll)
lm:dll "bgfx-dll" {
    windows = {
        links = {
            "gdi32",
            "psapi",
            "user32"
        }
    },
    macos = {
        frameworks = {
            "Cocoa",
            "QuartzCore",
            "OpenGL",
        },
        ldflags = {
            "-weak_framework", "Metal",
            "-weak_framework", "MetalKit",
        }
    }
}
