local lm = require "luamake"

local Rp3dBuildDir = "@../$builddir/reactphysics3d/"

lm:build "reactphysics3d_init" {
    "cmake",
    "-DCMAKE_BUILD_TYPE="..lm.mode,
    lm.os == "ios" and {
        "-DCMAKE_TOOLCHAIN_FILE=../ios-cmake/ios.toolchain.cmake",
        "-DPLATFORM=OS64",
        "-DENABLE_BITCODE=TRUE",
        "-DENABLE_VISIBILITY=TRUE",
    },
    "-DRP3D_LOGS_ENABLED=ON",
    "-G", "Ninja",
    "-S", "@../reactphysics3d",
    "-B", Rp3dBuildDir,
    pool = "console",
}

lm:build "reactphysics3d_make" {
    "ninja", "-C", Rp3dBuildDir,
    pool = "console",
}

lm:build "reactphysics3d_clean" {
    "ninja", "-C", Rp3dBuildDir, "-t", "clean",
    pool = "console",
}
