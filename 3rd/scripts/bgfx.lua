local lm = require "luamake"

local SETENV = lm.hostshell == "cmd" and "set" or "export"
local BGFX_OS
local BGFX_ARGS
local BGFX_BINS
local BGFX_MAKEFILE
local BGFX_EXE
local BGFX_SHARED_LIB
local EnableEditor = true

if lm.compiler == "msvc" then
    BGFX_OS = "windows"
    BGFX_ARGS = {"--with-windows=10.0", "vs2019"}
    BGFX_BINS = "../bgfx/.build/win64_vs2019/bin/"
    BGFX_EXE = ".exe"
    BGFX_SHARED_LIB = "bgfx-shared-lib"..lm.mode..".dll"
elseif lm.os == "windows" then
    BGFX_OS = "windows"
    BGFX_ARGS = {"--os=windows", "--gcc=mingw-gcc", "gmake"}
    BGFX_BINS = "../bgfx/.build/win64_mingw-gcc/bin/"
    BGFX_MAKEFILE = "@../bgfx/.build/projects/gmake-mingw-gcc"
    BGFX_EXE = ".exe"
    BGFX_SHARED_LIB = "bgfx-shared-lib"..lm.mode..".dll"
elseif lm.os == "macos" then
    BGFX_OS = "darwin"
    BGFX_ARGS = {"--gcc=osx-arm64", "gmake"}
    BGFX_BINS = "../bgfx/.build/osx-arm64/bin/"
    BGFX_MAKEFILE = "@../bgfx/.build/projects/gmake-osx-arm64"
    BGFX_EXE = ""
    BGFX_SHARED_LIB = "libbgfx-shared-lib"..lm.mode..".dylib"
elseif lm.os == "ios" then
    EnableEditor = false
    BGFX_OS = "darwin"
    BGFX_ARGS = {"--gcc=ios-arm64", "gmake"}
    BGFX_BINS = "../bgfx/.build/ios-arm64/bin/"
    BGFX_MAKEFILE = "@../bgfx/.build/projects/gmake-ios-arm64"
end

GENIE = ("../bx/tools/bin/%s/genie"):format(BGFX_OS)
if lm.hostshell == "cmd" then
    GENIE = GENIE:gsub("/", "\\")
end

lm:shell "bgfx_init" {
    SETENV, "BGFX_CONFIG=MAX_VIEWS=1024", "&&",
    "cd", "@../bgfx", "&&",
    GENIE, "--with-tools", "--with-shared-lib", "--with-dynamic-runtime", "--with-examples", BGFX_ARGS,
    pool = "console",
}

if lm.compiler == "msvc" then
    local msvc = require "msvc"
    local MSBuild = msvc:installpath() / "MSBuild" / "Current" / "Bin" / "MSBuild.exe"
    lm:build "bgfx_build" {
        MSBuild, "/nologo", "@../bgfx/.build/projects/vs2019/bgfx.sln", "/m", "/v:m", "/t:build", ([[/p:Configuration=%s,Platform=x64]]):format(lm.mode),
        pool = "console",
    }
else
    local BgfxMake = {"make", "--no-print-directory", "-R", "-C", BGFX_MAKEFILE, "config="..lm.mode.."64", "-j8" }
    lm:build "bgfx_build" {
        BgfxMake, "bgfx", "bx", "bimg", "bimg_decode",
        EnableEditor and {"bgfx-shared-lib","shaderc","texturec"},
        pool = "console",
    }
end

lm:build "bgfx_clean" {
    "make", "-C", BGFX_MAKEFILE, "clean",
    pool = "console",
}

if EnableEditor then
    lm:copy "copy_bgfx_texturec" {
        input = BGFX_BINS .. "texturec"..lm.mode..BGFX_EXE,
        output = "$bin/texturec"..BGFX_EXE,
        deps = "bgfx_build",
    }
    
    lm:copy "copy_bgfx_shaderc" {
        input = BGFX_BINS .. "shaderc"..lm.mode..BGFX_EXE,
        output = "$bin/shaderc"..BGFX_EXE,
        deps = "bgfx_build",
    }
    
    lm:copy "copy_bgfx_shared_lib" {
        input = BGFX_BINS .. BGFX_SHARED_LIB,
        output = "$bin/bgfx-core.dll",
        deps = "bgfx_build",
    }
    
    lm:copy "copy_bgfx_shader" {
        input = "../bgfx/src/bgfx_shader.sh",
        output = "../../packages/resources/shaders/bgfx_shader.sh",
    }
    
    lm:copy "copy_bgfx_compute" {
        input = "../bgfx/src/bgfx_compute.sh",
        output = "../../packages/resources/shaders/bgfx_compute.sh",
    }
    
    lm:copy "copy_bgfx_examples_common" {
        input = "../bgfx/examples/common/common.sh",
        output = "../../packages/resources/shaders/common.sh",
    }
    
    lm:copy "copy_bgfx_examples_shaderlib" {
        input = "../bgfx/examples/common/shaderlib.sh",
        output = "../../packages/resources/shaders/shaderlib.sh",
    }
    
    lm:phony "bgfx_make" {
        deps = {
            "copy_bgfx_texturec",
            "copy_bgfx_shaderc",
            "copy_bgfx_shared_lib",
            "copy_bgfx_shader",
            "copy_bgfx_compute",
            "copy_bgfx_examples_common",
            "copy_bgfx_examples_shaderlib",
        }
    }
else
    lm:phony "bgfx_make" {
        deps = "bgfx_build"
    }
end
