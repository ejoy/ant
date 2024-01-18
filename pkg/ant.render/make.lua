local lm = require "luamake"

local ROOT <const> = "../../"

lm:lua_source "render_core"{
    includes = {
        ROOT .. "3rd/bgfx/include",
        ROOT .. "3rd/bx/include",
        ROOT .. "clibs/bgfx",
        ROOT .. "3rd/math3d",
        ROOT .. "clibs/foundation",
        ROOT .. "clibs/luabind",
        ROOT .. "3rd/glm",
        ROOT .. "3rd/luaecs",
        ROOT .. "clibs/ecs",
        ROOT .. "pkg/ant.resource_manager/src",
        ROOT .. "pkg/ant.material",
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
        ROOT .. "3rd/math3d",
        ROOT .. "clibs/luabind",
        ROOT .. "3rd/luaecs",
        ROOT .. "3rd/glm",
        ROOT .. "clibs/ecs",
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