local ecs   = ...
local world = ecs.world
local w     = world.w

local efk_cb    = require "effekseer.callback"
local efk       = require "efk"

local fs        = require "filesystem"

local renderpkg = import_package "ant.render"
local fbmgr     = renderpkg.fbmgr
local viewidmgr = renderpkg.viewidmgr

local assetmgr  = import_package "ant.asset"

local itimer    = ecs.import.interface "ant.timer|itimer"

local efk_sys = ecs.system "efk_system"

local FxFiles = {}
do
    local FxNames = {
        sprite_unlit ={
            vs = "sprite_unlit_vs.fx.sc",
            fs = "model_unlit_ps.fx.sc",
            varying_path = "sprite_Unlit_varying.def.sc",
        },
        sprite_lit = {
            vs = "sprite_lit_vs.fx.sc", 
            fs = "model_lit_ps.fx.sc",
            varying_path = "sprite_Lit_varying.def.sc",
        },
        sprite_distortion = {
            vs = "sprite_distortion_vs.fx.sc", 
            fs = "model_distortion_ps.fx.sc",
            varying_path = "sprite_BackDistortion_varying.def.sc",
        },
        sprite_adv_unlit = {
            vs = "ad_sprite_unlit_vs.fx.sc", 
            fs = "ad_model_unlit_ps.fx.sc",
            varying_path = "sprite_AdvancedUnlit_varying.def.sc",
        },
        sprite_adv_lit = {
            vs = "ad_sprite_lit_vs.fx.sc", 
            fs = "ad_model_lit_ps.fx.sc",
            varying_path = "sprite_AdvancedLit_varying.def.sc",
        },
        sprite_adv_distortion = {
            vs = "ad_sprite_distortion_vs.fx.sc", 
            fs = "ad_model_distortion_ps.fx.sc",
            varying_path = "sprite_AdvancedBackDistortion_varying.def.sc",
        },

        model_unlit = {
            vs = "model_unlit_vs.fx.sc", 
            fs = "model_unlit_ps.fx.sc",
            varying_path = "model_Unlit_varying.def.sc",
        },
        model_lit = {
            vs = "model_lit_vs.fx.sc", 
            fs = "model_lit_ps.fx.sc",
            varying_path = "model_Lit_varying.def.sc",
        },
        model_distortion = {
            vs = "model_distortion_vs.fx.sc", 
            fs = "model_distortion_ps.fx.sc",
            varying_path = "model_BackDistortion_varying.def.sc",
        },
        model_adv_unlit = {
            vs = "ad_model_unlit_vs.fx.sc", 
            fs = "ad_model_unlit_ps.fx.sc",
            varying_path = "model_AdvancedUnlit_varying.def.sc",
        },
        model_adv_lit = {
            vs = "ad_model_lit_vs.fx.sc", 
            fs = "ad_model_lit_ps.fx.sc",
            varying_path = "model_Advancedlit_varying.def.sc",
        },
        model_adv_distortion = {
            vs = "ad_model_distortion_vs.fx.sc",
            fs = "ad_model_distortion_ps.fx.sc",
            varying_path = "model_AdvancedBackDistortion_varying.def.sc",
        },
    }

    for name, fx in pairs(FxNames) do
        local pkgpath = "/pkg/ant.efk/efkbgfx/shaders/"
        FxFiles[name] = assetmgr.load_fx{
            vs = pkgpath .. fx.vs,
            fs = pkgpath .. fx.fs,
            varying_path = pkgpath .. fx.varying_path,
        }
    end
end

local function shader_load(materialfile, shadername, stagetype)
    assert(materialfile == nil)
    local fx = assert(FxFiles[shadername], ("unkonw shader name:%s"):format(shadername))
    return fx[stagetype]
end


local TEXTURE_LOADED = {}
local function texture_load(texname, srgb)
    --TODO: need use srgb texture
    local tex = assetmgr.resource(texname)
    TEXTURE_LOADED[tex.handle] = tex
    return tex.handle
end

local function texture_unload(texhandle)
    local tex = TEXTURE_LOADED[texhandle]
    assetmgr.unload(tex)
end

local function error_handle(msg)
    error(msg)
end

local efk_cb_handle, efk_ctx
function efk_sys:init()
    efk_cb_handle =  efk_cb.callback{
        shader_load     = shader_load,
        texture_load    = texture_load,
        texture_unload  = texture_unload,
        error           = error_handle,
    }

    efk_ctx = efk.create(
        2000, viewidmgr.get "effect_view",
        efk_cb.shader_load,
        efk_cb.texture_load,
        efk_cb.texture_get,
        efk_cb.texture_unload, efk_cb_handle)
end

local function read_file(filename)
    local f<close> = fs.open(fs.path(filename), "rb")
    return f:read "a"
end

local function load_efk(filename)
    --TODO: not share every effect??
    return {
        handle = efk_ctx:create_effect(read_file(filename))
    }
end

function efk_sys:entity_init()
    for e in w:select "INIT efk:update" do
        e.efk = load_efk(e.efk)
    end
end

local mq_vr_mb = world:sub{"viewrect_changed", "main_queue"}

local function update_framebuffer_texutre()
    local mq = w:singleton("maiqn_queue", "render_target:in")
    local rt = mq.render_target
    local fb = fbmgr.get(rt.fb_idx)
    efk_cb_handle.background = fbmgr.get_rb(fb[1]).handle
    efk_cb_handle.depth = fbmgr.get_depth(fb).handle
end

function efk_sys:init_world()
    update_framebuffer_texutre()
end

function efk_sys:data_changed()
    for _ in mq_vr_mb:each() do
       update_framebuffer_texutre() 
    end
end

--TODO: need remove, should put it on the ltask
function efk_sys:render_submit()
    efk_ctx:render(itimer.delta())
end


local iefk = ecs.interface "iefk"
function iefk.play(e, p)
    return efk_ctx:play(e.efk.handle, p)
end

function iefk.stop(efkhandle)
    efk_ctx:stop(efkhandle)
end