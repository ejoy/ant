local lm = require "luamake"

local EnableEditor = lm.os ~= "ios"
local OzzBuildDir = "@../$builddir/ozz-animation/"

local EXE = ""
if lm.os == "windows" then
    EXE = ".exe"
end

lm:build "ozz-animation_init" {
    "cmake",
    "-DCMAKE_BUILD_TYPE="..lm.mode,
    lm.os == "ios" and {
        "-DCMAKE_TOOLCHAIN_FILE=../ios-cmake/ios.toolchain.cmake",
        "-DPLATFORM=OS64",
        "-DENABLE_BITCODE=TRUE",
    },
    "-Dozz_build_msvc_rt_dll=ON",
    "-Dozz_build_samples=OFF",
    "-Dozz_build_fbx=OFF",
    "-Dozz_build_howtos=OFF",
    "-Dozz_build_cpp11=ON",
    "-Dozz_build_tests=OFF",
    "-DEMSCRIPTEN=FALSE",
    not EnableEditor and {
        "-Dozz_build_tools=OFF",
        "-Dozz_build_gltf=OFF"
    },
    "-G", "Ninja",
    "-S", "@../ozz-animation",
    "-B", OzzBuildDir,
    pool = "console",
}

lm:build "ozz-animation_build" {
    "ninja", "-C", OzzBuildDir,
    pool = "console",
}

if EnableEditor then
    lm:copy "ozz-animation_make" {
        input = OzzBuildDir .. "src/animation/offline/gltf/gltf2ozz"..EXE,
        output = "$bin/gltf2ozz"..EXE,
        deps = "ozz-animation_build",
    }
else
    lm:phony "ozz-animation_make" {
        deps = "ozz-animation_build"
    }
end

lm:build "ozz-animation_clean" {
    "ninja", "-C", OzzBuildDir, "-t", "clean",
    pool = "console",
}
