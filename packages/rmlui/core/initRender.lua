local rmlui = require "rmlui"

local function create_shaders()
    local assetmgr = import_package "ant.asset"
    local function load_shaders(def)
        local shaders = {}
        for k, v in pairs(def) do
            shaders[k] = assetmgr.load_fx(v)
            v.setting["ENABLE_CLIP_RECT"] = 1
            shaders[k .. "_cr"] = assetmgr.load_fx(v)
        end
        return shaders
    end
    local shaders = load_shaders {
        image = {
            fs = "/pkg/ant.resources/shaders/ui/fs_image.sc",
            vs = "/pkg/ant.resources/shaders/ui/vs_image.sc",
            setting = {}
        },
        font = {
            fs = "/pkg/ant.resources/shaders/font/fs_uifont.sc",
            vs = "/pkg/ant.resources/shaders/font/vs_uifont.sc",
            setting = {},
        },
        font_outline = {
            fs = "/pkg/ant.resources/shaders/font/fs_uifont.sc",
            vs = "/pkg/ant.resources/shaders/font/vs_uifont.sc",
            setting = {OUTLINE_EFFECT=1},
        },
        font_shadow ={
            fs = "/pkg/ant.resources/shaders/font/fs_uifont.sc",
            vs = "/pkg/ant.resources/shaders/font/vs_uifont.sc",
            setting = {SHADOW_EFFECT=1},
        },
    }
    shaders.debug_draw = assetmgr.load_fx {
        vs = "/pkg/ant.resources/shaders/ui/vs_debug.sc",
        fs = "/pkg/ant.resources/shaders/ui/fs_debug.sc",
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
    rmlui.RmlInitialise(t)
end
