local S = {}

local ltask     = require "ltask"
local bgfx      = require "bgfx"

local fs        = require "filesystem"

local efk_cb    = require "effekseer.callback"
local efk       = require "efk"

local FI        = require "fileinterface"

local cr        = import_package "ant.compile_resource"
local mathpkg   = import_package "ant.math"
local mc        = mathpkg.constant
local renderpkg = import_package "ant.render"

local viewidmgr = renderpkg.viewidmgr
local assetmgr  = import_package "ant.asset"
renderpkg.init_bgfx()

local effect_viewid<const> = viewidmgr.get "effect_view"

bgfx.init()
cr.init()
assetmgr.init()

local quit

local FxFiles = {};

local function preopen(filename)
    local _ <close> = fs.switch_sync()
    return cr.compile(filename):string()
end

local filefactory = FI.factory { preopen = preopen }

local function shader_load(materialfile, shadername, stagetype)
    assert(materialfile == nil)
    local fx = assert(FxFiles[shadername], ("unkonw shader name:%s"):format(shadername))
    return fx[stagetype]
end

local TEXTURES = {}

local function texture_load(texname, srgb)
    --TODO: need use srgb texture
    assert(texname:match "^/pkg" ~= nil)
    local tex = TEXTURES[fs.path(texname):replace_extension "texture":string()]
    if not tex then
        print("[EFK ERROR]", debug.traceback(("%s: need corresponding .texture file to describe how this png file to use"):format(texname)) )
    end
    return tex
end

local function texture_unload(texhandle)
    --TODO
end

local function error_handle(msg)
    print("[EFK ERROR]", debug.traceback(msg))
end

local efk_cb_handle, efk_ctx

local ident_mat<const> = ("f"):rep(16):pack(
    1.0, 0.0, 0.0, 0.0,
    0.0, 1.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0,
    0.0, 0.0, 0.0, 1.0)

local viewmat, projmat = ident_mat, ident_mat
local deltatime = 0

function S.init(fx_files)
    FxFiles = fx_files
    efk_cb_handle =  efk_cb.callback{
        shader_load     = shader_load,
        texture_load    = texture_load,
        texture_unload  = texture_unload,
        texture_map     = {},
        error           = error_handle,
    }

    efk_ctx = efk.startup{
        max_count       = 2000,
        viewid          = effect_viewid,
        shader_load     = efk_cb.shader_load,
        texture_load    = efk_cb.texture_load,
        texture_get     = efk_cb.texture_get,
        texture_unload  = efk_cb.texture_unload,
        userdata        = {
            callback = efk_cb_handle,
            filefactory = filefactory,
        }
    }
end

function S.update(view, proj, dt)
    viewmat, projmat = view, proj
    deltatime = dt
end

function S.update_cb_data(background_handle, depth)
    efk_cb_handle.background = background_handle
    efk_cb_handle.depth = depth
end

function S.create(filename)
    return efk_ctx:create(filename)
end

local function shutdown()
    if efk_ctx then
        efk.shutdown(efk_ctx)
        bgfx.shutdown()
        efk_ctx = nil
    end
end

function S.preload_texture(texture, id)
    if not TEXTURES[texture] then
        TEXTURES[texture] = id
    end
end

function S.is_alive(handle)
    return efk_ctx:is_alive(handle)
end

function S.play(handle, mat, speed)
    return efk_ctx:play(handle, mat, speed)
end

function S.update_state(handle, s)
    if s.delete then
        efk_ctx:destroy(handle)
        return false
    end

    if s.stop then
        efk_ctx:stop(handle, s.delay)
    end

    if s.mat then
        efk_ctx:update_transform(handle, s.mat)
    end

    if s.speed then
        efk_ctx:set_speed(handle, s.speed)
    end

    if s.pause ~= nil then
        efk_ctx:pause(handle, s.pause)
    end

    if s.time then
        efk_ctx:set_time(handle, s.time)
    end

    if s.visible then
        efk_ctx:set_visible(handle, s.visible)
    end

    return true
end

function S.quit()
    quit = {}
    ltask.wait(quit)
    shutdown()
    ltask.quit()
end

ltask.fork(
function ()
    bgfx.encoder_create "efx"
    while not quit do
        if efk_ctx then
            efk_ctx:render(viewmat, projmat, deltatime)
        end
        bgfx.encoder_frame()
    end
    bgfx.encoder_destroy()
    ltask.wakeup(quit)
end)

return S