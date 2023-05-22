local lm = require "luamake"

lm.cxx = "c++17"

if lm.mode == "debug" then
    lm.defines = {
        "BX_CONFIG_DEBUG=1",
        "BGFX_CONFIG_DEBUG_UNIFORM=0",
    }
else
    lm.defines = {
        "BX_CONFIG_DEBUG=0",
    }
end


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

lm.android  = {
    flags = "-fPIC",
    target = "aarch64-linux-android33"
}

lm.clang = {
    flags = {
        "-Wno-unknown-warning-option",
        "-Wno-tautological-constant-compare",
        "-Wno-unused-variable",
        "-Wno-unused-but-set-variable"
    }
}
