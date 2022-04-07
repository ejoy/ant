local ecs   = ...
local world = ecs.world
local w     = world.w

local efk_cb    = require "effekseer.callback"
local efk       = require "efk"

local fs        = require "filesystem"

local renderpkg = import_package "ant.render"
local fbmgr     = renderpkg.fbmgr
local viewidmgr = renderpkg.viewidmgr
local cr        = import_package "ant.compile_resource"

local assetmgr  = import_package "ant.asset"

local itimer    = ecs.import.interface "ant.timer|itimer"

local efk_sys = ecs.system "efk_system"

local function KEY(modeltype, shadertype, stage)
    return ("%s_%s_%s"):format(modeltype, shadertype, stage)
end

local FxFiles = {}
do
    local shadertypes = {"unlit", "lit", "distortion"}
    for _, modeltype in ipairs{"sprite", "model"} do
        for _, shadertype in ipairs(shadertypes) do
            local function to_fxfile()
                local vskey = KEY(modeltype, shadertype, "vs")
                local fskey = KEY(modeltype, shadertype, "ps")
                return {
                    vs = ("/pkg/ant.efk/efkbgfx/shaders/%s.fx.sc"):format(vskey),
                    fs = ("/pkg/ant.efk/efkbgfx/shaders/%s.fx.sc"):format(fskey),
                }
            end
            
            local fxname = modeltype .. "_" .. shadertype
            FxFiles[fxname] = assetmgr.load_fx(to_fxfile())
        end
    end
end

local STAGES<const> = {
    vs = "vs",
    fs = "ps",
}

local function shader_load(materialfile, shadername, stagetype)
    assert(materialfile == nil)
    local modeltype, shadertype = shadername:match "(%w+)_(%w+)"
    local key = ""
    if modeltype == nil then
        key = "ad_"
        modeltype, shadertype = shadername:match "(%w+)_adv_(%w+)"
    end

    if modeltype == nil then
        error(("invalid name:%s, %s"):format(shadername, stagetype))
    end

    if modeltype ~= "sprite" and modeltype ~= "model" then
        error(("model type: %s, should only be : 'sprite' or 'model'"):format(modeltype))
    end

    key = key .. KEY(modeltype, shadertype, STAGES[stagetype])
    return cr.load_shader(ShaderFiles[key])
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