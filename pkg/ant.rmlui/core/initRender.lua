local rmlui = require "rmlui"
local bgfx = require "bgfx"
import_package "ant.service".init_bgfx()
local renderpkg = import_package "ant.render"

local function create_shaders()
    local ltask = require "ltask"
    local ServiceResource = ltask.uniqueservice "ant.compile_resource|resource"
    local function load_material(filename)
        return ltask.call(ServiceResource, "material_create", filename)
    end
    local function push_uniforms(a, b)
        for _, u in ipairs(b) do
            local name = u.name
            local handle = u.handle & 0xFFFF
            assert(a[name] == handle or a[name] == nil)
            a[name] = handle
        end
    end

    local shaders = {
        font            = "/pkg/ant.rmlui/materials/font.material",
        font_cr         = "/pkg/ant.rmlui/materials/font_cr.material",
        font_outline    = "/pkg/ant.rmlui/materials/font_outline.material",
        font_outline_cr = "/pkg/ant.rmlui/materials/font_outline_cr.material",
        font_shadow     = "/pkg/ant.rmlui/materials/font_shadow.material",
        font_shadow_cr  = "/pkg/ant.rmlui/materials/font_shadow_cr.material",
        image           = "/pkg/ant.rmlui/materials/image.material",
        image_cr        = "/pkg/ant.rmlui/materials/image_cr.material",
        image_gray      = "/pkg/ant.rmlui/materials/image_gray.material",
        image_cr_gray   = "/pkg/ant.rmlui/materials/image_cr.material",
        debug_draw      = "/pkg/ant.rmlui/materials/debug_draw.material",
    }

    local progs = {}
    local uniforms = {}

    local tasks = {}
    for k, v in pairs(shaders) do
        tasks[#tasks+1] = {function ()
            local shader = load_material(v)
            push_uniforms(uniforms, shader.fx.uniforms)
            progs[k] = shader.fx.prog & 0xFFFF
        end}
    end
    for _ in ltask.parallel(tasks) do
    end

    progs.uniforms = uniforms
    return progs
end

local shaders = create_shaders()

return function(t)
    local declmgr = renderpkg.declmgr
    local layouhandle = declmgr.get "p2|c40niu|t20".handle
    t.layout  = layouhandle
    t.shader = shaders
    t.callback = require "core.callback"
    t.font_mgr = bgfx.fontmanager()
    rmlui.RmlInitialise(t)
end
