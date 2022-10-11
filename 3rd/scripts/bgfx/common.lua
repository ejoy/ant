local lm = require "luamake"

lm.cxx = "c++17"

lm.defines = "BX_CONFIG_DEBUG=" .. (lm.mode == "debug" and 1 or 0)

lm.msvc = {
    defines = {
        "_CRT_SECURE_NO_WARNINGS",
        lm.mode == "debug" and "_DISABLE_STRING_ANNOTATION",
    },
    includes = lm.BxDir / "include/compat/msvc",
}

lm.mingw = {
    includes = lm.BxDir / "include/compat/mingw",
}

lm.linux  = {
    flags = "-fPIC"
}

lm.macos = {
    includes = lm.BxDir / "include/compat/osx",
}

lm.ios = {
    includes = lm.BxDir / "include/compat/ios",
    flags = {
        "-fembed-bitcode",
        "-Wno-unused-function"
    }
}

lm.clang = {
    flags = {
        "-Wno-unknown-warning-option",
        "-Wno-tautological-constant-compare",
        "-Wno-unused-variable",
        "-Wno-unused-but-set-variable"
    }
}
