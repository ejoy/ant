local lm = require "luamake"

lm:source_set "reactphysics3d" {
    rootdir = "../reactphysics3d",
    includes = "include",
    sources = {
        "src/*.cpp"
    },
    clang = {
        flags = {
            "-Wno-defaulted-function-deleted",
            "-Wno-unused-private-field",
            "-Wno-mismatched-tags"
        }
    }
}

lm:phony "reactphysics3d_make" {
    deps = "reactphysics3d"
}
