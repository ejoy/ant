local lm = require "luamake"

require "utf8.support-utf8"

lm:exe "texturec" {
    rootdir = lm.BimgDir,
    deps = {
        "bimg-decode",
        "bimg-encode",
        "bimg",
        "bx",
    },
    includes = {
        lm.BxDir / "include",
        lm.BgfxDir / "include",
        "include",
        "3rdparty/iqa/include"
    },
    sources = {
        "tools/texturec/texturec.cpp",
    },
    windows = {
        deps = "bgfx-support-utf8",
        links = {
            "psapi"
        }
    }
}
