local lm = require "luamake"

lm:lua_src "render_core" {
    confs = { "glm" },
    includes = {
        lm.AntDir .. "/3rd/bgfx/include",
        lm.AntDir .. "/3rd/bx/include",
        lm.AntDir .. "/clibs/bgfx",
        lm.AntDir .. "/3rd/math3d",
        lm.AntDir .. "/clibs/foundation",
        lm.AntDir .. "/clibs/luabind",
        lm.AntDir .. "/3rd/luaecs",
        lm.AntDir .. "/clibs/ecs",
        lm.AntDir .. "/pkg/ant.resource_manager/src",
        lm.AntDir .. "/pkg/ant.material",
    },
    defines = {
        lm.mode == "debug" and "RENDER_DEBUG" or nil,
    },
    objdeps = "compile_ecs",
    sources = {
        "render/render.cpp",
        "render/hash.cpp",
        "render/queue.cpp",
        "render/mesh.cpp",
    },
}

lm:lua_src "render" {
    confs = { "glm" },
    includes = {
        lm.AntDir .. "/3rd/math3d",
        lm.AntDir .. "/clibs/luabind",
        lm.AntDir .. "/3rd/luaecs",
        lm.AntDir .. "/clibs/ecs",
    },
    sources = {
        "cull/cull.cpp",
    },
    objdeps = "compile_ecs",
    deps = {
        "material_core",
        "render_core",
    }
}