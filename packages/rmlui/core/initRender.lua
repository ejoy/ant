local rmlui = require "rmlui"
local assetmgr = import_package "ant.asset"
local cr = import_package "ant.compile_resource"
cr.init()

local function create_shaders()
    local shaders = {
        font            = assetmgr.load_fx "/pkg/ant.rmlui/materials/font.material",
        font_cr         = assetmgr.load_fx "/pkg/ant.rmlui/materials/font_cr.material",
        font_outline    = assetmgr.load_fx "/pkg/ant.rmlui/materials/font_outline.material",
        font_outline_cr = assetmgr.load_fx "/pkg/ant.rmlui/materials/font_outline_cr.material",
        font_shadow     = assetmgr.load_fx "/pkg/ant.rmlui/materials/font_shadow.material",
        font_shadow_cr  = assetmgr.load_fx "/pkg/ant.rmlui/materials/font_shadow_cr.material",
        image           = assetmgr.load_fx "/pkg/ant.rmlui/materials/image.material",
        image_cr        = assetmgr.load_fx "/pkg/ant.rmlui/materials/image_cr.material",
        debug_draw      = assetmgr.load_fx "/pkg/ant.rmlui/materials/debug_draw.material",
    }

    local function push_uniforms(a, b)
        for _, u in ipairs(b) do
            local name = u.name
            local handle = u.handle & 0xFFFF
            assert(a[name] == handle or a[name] == nil)
            a[name] = handle
        end
    end
    local progs = {}
    local uniforms = {}
    for k, v in pairs(shaders) do
        push_uniforms(uniforms, v.fx.uniforms)
        progs[k] = v.fx.prog & 0xFFFF
    end
    progs.uniforms = uniforms
    return progs
end

local shaders = create_shaders()

return function(t)
    local renderpkg = import_package "ant.render"
    local declmgr = renderpkg.declmgr
    local layouhandle = declmgr.get "p2|c40niu|t20".handle
    t.layout  = layouhandle
    t.shader = shaders
    t.callback = require "core.callback"
    rmlui.RmlInitialise(t)
end
