local lm = require "luamake"

local EnableEditor = lm.os ~= "ios" and lm.os ~= "android"

lm.rootdir = lm.AntDir .. "/3rd/ozz-animation"

lm:source_set "ozz-animation-json" {
    includes = "extern/jsoncpp/dist",
    sources = "extern/jsoncpp/dist/jsoncpp.cpp",
}

lm:source_set "ozz-animation-base" {
    includes = "include",
    sources = "src/base/**/*.cc",
}

lm:source_set "ozz-animation-runtime" {
    includes = {"include", "src"},
    sources = "src/animation/runtime/*.cc",
}

lm:source_set "ozz-animation-offline" {
    includes = {"include", "src"},
    sources = {
        "src/animation/offline/*.cc",
        "!src/animation/offline/fbx/*.cc",
        "!src/animation/offline/gltf/*.cc",
        "!src/animation/offline/tools/*.cc",
    }
}

lm:source_set "ozz-animation-geometry" {
    includes = "include",
    sources = "src/geometry/runtime/*.cc",
}

if not EnableEditor then
    return
end

lm:exe "gltf2ozz" {
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
        sources = lm.AntDir .. "/3rd/bgfx.luamake/utf8/utf8.rc"
    },
    linux = {
        links = {
            "m"
        }
    }
}
