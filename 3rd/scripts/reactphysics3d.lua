local lm = require "luamake"

local Rp3dBuildDir = "@../$builddir/reactphysics3d/" .. lm.mode .. "/"

lm:build "reactphysics3d_init" {
    "cmake", "-DCMAKE_BUILD_TYPE="..lm.mode,
    {
        "-DRP3D_LOGS_ENABLED=ON",
    },
    "-G", "Ninja",
    "-S", "@../reactphysics3d",
    "-B", Rp3dBuildDir,
    pool = "console",
}


lm:build "reactphysics3d_make" {
    "ninja", "-C", Rp3dBuildDir,
    pool = "console",
}
