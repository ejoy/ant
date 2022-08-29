local rmlui = require "rmlui"
local datalist = require "datalist"
local fs = require "filesystem"
local function readfile(filename)
    local f <close> = fs.open(fs.path(filename))
    return f:read "a"
end

local function load_material(filename)
    local fxc = datalist.parse(readfile(filename)).fx
    fxc.setting = fxc.setting or {}
    local cr = import_package "ant.compile_resource"
    return cr.load_fx(fxc)
end

local function create_shaders()
    local shaders = {
        font            = load_material "/pkg/ant.rmlui/materials/font.material",
        font_cr         = load_material "/pkg/ant.rmlui/materials/font_cr.material",
        font_outline    = load_material "/pkg/ant.rmlui/materials/font_outline.material",
        font_outline_cr = load_material "/pkg/ant.rmlui/materials/font_outline_cr.material",
        font_shadow     = load_material "/pkg/ant.rmlui/materials/font_shadow.material",
        font_shadow_cr  = load_material "/pkg/ant.rmlui/materials/font_shadow_cr.material",
        image           = load_material "/pkg/ant.rmlui/materials/image.material",
        image_cr        = load_material "/pkg/ant.rmlui/materials/image_cr.material",
        debug_draw      = load_material "/pkg/ant.rmlui/materials/debug_draw.material",
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
