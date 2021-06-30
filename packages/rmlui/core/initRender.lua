local rmlui = require "rmlui"

local function create_shaders()
    local assetmgr = import_package "ant.asset"
    local function create_font_shader(effectname)
        local setting = {}
        if effectname then
            setting[effectname] = 1
        end
        return {
            fs = "/pkg/ant.resources/shaders/font/fs_uifont.sc",
            vs = "/pkg/ant.resources/shaders/font/vs_uifont.sc",
            setting = setting,
        }
    end

    local shader_defines = {
        image = {
            fs = "/pkg/ant.resources/shaders/ui/fs_image.sc",
            vs = "/pkg/ant.resources/shaders/ui/vs_image.sc",
            setting = {}
        },
        font = create_font_shader(),
        font_outline = create_font_shader "OUTLINE_EFFECT",
        font_shadow = create_font_shader "SHADOW_EFFECT",
    }

    local function create_shaders(def)
        local shaders = {}
        for k, v in pairs(def) do
            shaders[k] = assetmgr.load_fx(v)
            v.setting["ENABLE_CLIP_RECT"] = 1
            shaders[k .. "_cr"] = assetmgr.load_fx(v)
        end
        return shaders
    end
    local shaders = create_shaders(shader_defines)
    shaders.debug_draw = assetmgr.load_fx{
        vs = "/pkg/ant.resources/shaders/ui/vs_debug.sc",
        fs = "/pkg/ant.resources/shaders/ui/fs_debug.sc",
    }
    return shaders
end

return function(t)
    local renderpkg = import_package "ant.render"
    local declmgr = renderpkg.declmgr
    local layouhandle = declmgr.get "p2|c40niu|t20".handle
    t.layout  = layouhandle
    t.shader = create_shaders()
    rmlui.RmlInitialise(t)
end
