local rmlui = require "rmlui"

local function create_shaders()
    local assetmgr = import_package "ant.asset"
    local shaders = {
        font            = assetmgr.load_fx "/pkg/ant.rmlui/fx/font.fx",
        font_cr         = assetmgr.load_fx "/pkg/ant.rmlui/fx/font_cr.fx",
        font_outline    = assetmgr.load_fx "/pkg/ant.rmlui/fx/font_outline.fx",
        font_outline_cr = assetmgr.load_fx "/pkg/ant.rmlui/fx/font_outline_cr.fx",
        font_shadow     = assetmgr.load_fx "/pkg/ant.rmlui/fx/font_shadow.fx",
        font_shadow_cr  = assetmgr.load_fx "/pkg/ant.rmlui/fx/font_shadow_cr.fx",
        image           = assetmgr.load_fx "/pkg/ant.rmlui/fx/image.fx",
        image_cr        = assetmgr.load_fx "/pkg/ant.rmlui/fx/image_cr.fx",
        debug_draw      = assetmgr.load_fx "/pkg/ant.rmlui/fx/debug_draw.fx"
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
        push_uniforms(uniforms, v.uniforms)
        progs[k] = v.prog & 0xFFFF
    end
    progs.uniforms = uniforms
    return progs
end

return function(t)
    local renderpkg = import_package "ant.render"
    local declmgr = renderpkg.declmgr
    local layouhandle = declmgr.get "p2|c40niu|t20".handle
    t.layout  = layouhandle
    t.shader = create_shaders()
    t.callback = require "core.callback"
    rmlui.RmlInitialise(t)
end
