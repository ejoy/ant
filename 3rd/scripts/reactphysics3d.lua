local lm = require "luamake"

lm:source_set "reactphysics3d" {
    rootdir = "../reactphysics3d",
    includes = "include",
    sources = {
        "src/**/*.cpp"
    },
    msvc = {
        flags = {
            "/wd4018",
            "/wd4099",
            "/wd4244",
            "/wd4267",
            "/wd4305",
            "/wd4715",
        }
    },
	mingw = {
		flags = {
			"-Wno-class-memaccess",
		}
	},
    clang = {
        flags = {
            "-Wno-defaulted-function-deleted",
            "-Wno-unused-private-field",
            "-Wno-mismatched-tags",
        }
    }
}
