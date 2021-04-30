local lm = require "luamake"

local OzzBuildDir = "$builddir/ozz-animation/"..lm.mode.."/"

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


lm:build "ozz-animation_make" {
    "{COPY}", OzzBuildDir .. "src/animation/offline/gltf/gltf2ozz.exe", "$bin/gltf2ozz.exe",
    deps = "ozz-animation_build",
}
