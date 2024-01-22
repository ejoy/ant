local lm = require "luamake"

lm:lua_source "render_core"{
    includes = {
        lm.AntDir .. "/3rd/bgfx/include",
        lm.AntDir .. "/3rd/bx/include",
        lm.AntDir .. "/clibs/bgfx",
        lm.AntDir .. "/3rd/math3d",
        lm.AntDir .. "/clibs/foundation",
        lm.AntDir .. "/clibs/luabind",
        lm.AntDir .. "/3rd/glm",
        lm.AntDir .. "/3rd/luaecs",
        lm.AntDir .. "/clibs/ecs",
        lm.AntDir .. "/pkg/ant.resource_manager/src",
        lm.AntDir .. "/pkg/ant.material",
    },
    defines = {
        "GLM_FORCE_QUAT_DATA_XYZW",
        lm.mode == "debug" and "RENDER_DEBUG" or nil,
    },
    objdeps = "compile_ecs",
    sources = {
        "render/render.cpp",
        "render/queue.cpp",
    },
}

lm:lua_source "render" {
    includes = {
        lm.AntDir .. "/3rd/math3d",
        lm.AntDir .. "/clibs/luabind",
        lm.AntDir .. "/3rd/luaecs",
        lm.AntDir .. "/3rd/glm",
        lm.AntDir .. "/clibs/ecs",
    },
    defines = {
        "GLM_FORCE_QUAT_DATA_XYZW",
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