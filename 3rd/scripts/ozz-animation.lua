local lm = require "luamake"

local EnableEditor = lm.os ~= "ios"

lm:source_set "ozz-animation-json" {
    rootdir = "../ozz-animation/extern/jsoncpp/dist",
    includes = ".",
    sources = "jsoncpp.cpp",
}

lm:source_set "ozz-animation-base" {
    rootdir = "../ozz-animation",
    includes = "include",
    sources = "src/base/**.cc",
}

lm:source_set "ozz-animation-runtime" {
    rootdir = "../ozz-animation",
    includes = {"include", "src"},
    sources = "src/animation/runtime/*.cc",
}

lm:source_set "ozz-animation-offline" {
    rootdir = "../ozz-animation",
    includes = {"include", "src"},
    sources = {
        "src/animation/offline/*.cc",
        "!src/animation/offline/fbx/*.cc",
        "!src/animation/offline/gltf/*.cc",
        "!src/animation/offline/tools/*.cc",
    }
}

lm:source_set "ozz-animation-geometry" {
    rootdir = "../ozz-animation",
    includes = "include",
    sources = "src/geometry/runtime/*.cc",
}

if not EnableEditor then
    return
end

lm:exe "gltf2ozz" {
    rootdir = "../ozz-animation",
    deps = {
        "ozz-animation-json",
        "ozz-animation-base",
        "ozz-animation-runtime",
        "ozz-animation-offline",
    },
    includes = {
        "include",
        "src",
        "extern/jsoncpp/dist"
    },
    sources = {
        "src/options/*.cc",
        "src/animation/offline/gltf/*.cc",
        "src/animation/offline/tools/*.cc",
        "!src/animation/offline/tools/dump2ozz.cc",
    },
    windows = {
        sources = "../scripts/utf8/utf8.rc"
    }
}
