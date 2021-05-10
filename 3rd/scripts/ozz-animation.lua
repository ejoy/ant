local lm = require "luamake"

local OzzBuildDir = "@../$builddir/ozz-animation/"..lm.mode.."/"

local EXE = ""
if lm.os == "windows" then
    EXE = ".exe"
end

lm:build "ozz-animation_init" {
    "cmake", "-DCMAKE_BUILD_TYPE="..lm.mode,
    {
        "-Dozz_build_msvc_rt_dll=ON",
        "-Dozz_build_samples=OFF",
        "-Dozz_build_fbx=OFF",
        "-Dozz_build_howtos=OFF",
        "-Dozz_build_cpp11=ON",
        "-Dozz_build_tests=OFF",
        "-DEMSCRIPTEN=FALSE"
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

lm:copy "ozz-animation_make" {
    input = OzzBuildDir .. "src/animation/offline/gltf/gltf2ozz"..EXE,
    output = "$bin/gltf2ozz"..EXE,
    deps = "ozz-animation_build",
}

lm:build "ozz-animation_clean" {
    "ninja", "-C", OzzBuildDir, "-t", "clean",
    pool = "console",
}
