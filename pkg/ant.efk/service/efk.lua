local S = {}

local math3d    = require "math3d"
local ltask     = require "ltask"
local bgfx      = require "bgfx"

local fs        = require "filesystem"

local efk_cb    = require "effekseer.callback"
local efk       = require "efk"

local FI        = require "fileinterface"

local setting   = import_package "ant.settings"
local DISABLE_EFK<const> = setting:get "efk/disable"

local bgfxmainS = ltask.queryservice "ant.hwi|bgfx_main"

local hwi       = import_package "ant.hwi"
hwi.init_bgfx()

local assetmgr  = import_package "ant.asset"

local effect_viewid<const> = hwi.viewid_get "effect_view"

bgfx.init()
assetmgr.init()

local function preopen(filename)
    local _ <close> = fs.switch_sync()
    return fs.path(filename):localpath():string()
end

local filefactory = FI.factory { preopen = preopen }

local function init_fx_files()
    local tasks = {}
    local FxFiles = {}
    for _, name in ipairs{
        "sprite_unlit",
        "sprite_lit",
        "sprite_distortion",
        "sprite_adv_unlit",
        "sprite_adv_lit",
        "sprite_adv_distortion",

        "model_unlit",
        "model_lit",
        "model_distortion",
        "model_adv_unlit",
        "model_adv_lit",
        "model_adv_distortion",
    } do
        tasks[#tasks+1] = {function ()
            local filename = ("/pkg/ant.efk/materials/%s.material"):format(name)
            local r = assetmgr.load_material(filename)
            FxFiles[name] = r.fx
        end}
    end

    for _, t in ltask.parallel(tasks) do
    end
    return FxFiles
end

local FxFiles = init_fx_files()

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

local efk_cb_handle = efk_cb.callback{
    shader_load     = shader_load,
    texture_load    = texture_load,
    texture_unload  = texture_unload,
    texture_map     = {},
    error           = error_handle,
}

local EFKCTX
local EFKFILES = {}

local function shutdown()
    if EFKCTX then
        efk.shutdown(EFKCTX)
        EFKCTX = nil
    end

    if next(EFKFILES) then
        error("efk file is not removed before 'shutdown'")
    end
end

function S.init()
    assert(not EFKCTX, "efk context need clean before efk service init")
    EFKCTX = efk.startup{
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

function S.exit()
    assert(not next(EFKFILES), "efk files should cleanup after shutdown")
    shutdown()
end

function S.update_cb_data(background_handle, depth)
    efk_cb_handle.background = background_handle
    efk_cb_handle.depth = depth
end

function S.create(filename)
    local info = EFKFILES[filename]
    if not info then
        log.info("Create efk file:", filename)
        info = {
            obj = EFKCTX:new(filename),
            count = 0,
        }
        EFKFILES[filename] = info
    end
    info.count = info.count + 1
    return EFKCTX:create(info.obj)
end

function S.destroy(filename, handle)
    local info = assert(EFKFILES[filename], "Invalid efk file: " .. filename)
    info.count = info.count - 1
    EFKCTX:destroy(handle)
    if 0 == info.count then
        log.info("Destroy efk file:", filename)
        EFKFILES[filename] = nil
        info.obj:release()
        info.obj = nil
    end
end

function S.preload_texture(texture, id)
    if not TEXTURES[texture] then
        TEXTURES[texture] = id
    end
end

function S.play(efkhandle, speed)
    EFKCTX:play(efkhandle, speed)
end

function S.is_alive(handle)
    return EFKCTX:is_alive(handle)
end

function S.set_stop(handle, delay)
    return EFKCTX:stop(handle, delay)
end

function S.set_time(handle, time)
    EFKCTX:set_time(handle, time)
end

function S.update_transform(handle, mat)
    EFKCTX:update_transform(handle, mat)
end

function S.update_hitch_transforms(handles, mats)
    for idx, handle in ipairs(handles) do
        local offset = 1+(idx-1)*64
        EFKCTX:update_transform(handle, mats:sub(offset, offset+64))
    end
end

function S.set_speed(handle, speed)
    EFKCTX:set_speed(handle, speed)
end

function S.set_pause(handle, p)
    EFKCTX:pause(handle, p)
end

function S.set_visible(handle, v)
    EFKCTX:set_visible(handle, v)
end

function S.quit()
    if not DISABLE_EFK then
        bgfx.encoder_destroy()
    end

    bgfx.shutdown()
    ltask.quit()
end

local loop = DISABLE_EFK and function () end or
function ()
    bgfx.encoder_create "efx"
    while true do
        if EFKCTX then
            local viewmat, projmat, deltatime = ltask.call(bgfxmainS, "fetch_world_camera")
            EFKCTX:render(viewmat, projmat, deltatime)
        end
        bgfx.encoder_frame()
    end
end

ltask.fork(
    loop
)

return S