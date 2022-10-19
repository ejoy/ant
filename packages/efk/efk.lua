local ecs   = ...
local world = ecs.world
local w     = world.w

local efk_cb    = require "effekseer.callback"
local efk       = require "efk"
local fs        = require "filesystem"
local math3d    = require "math3d"
local fileinterface = require "fileinterface"
local renderpkg = import_package "ant.render"
local fbmgr     = renderpkg.fbmgr
local viewidmgr = renderpkg.viewidmgr
local assetmgr  = import_package "ant.asset"
local cr        = import_package "ant.compile_resource"
local itimer    = ecs.import.interface "ant.timer|itimer"

local irq       = ecs.import.interface "ant.render|irenderqueue"

local efk_sys = ecs.system "efk_system"

local FxFiles = {};
local function init_fx_files()
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
        local filename = ("/pkg/ant.efk/materials/%s.material"):format(name)
        local r = assetmgr.resource(filename)
        FxFiles[name] = r.fx
    end
end

local function preopen(filename)
    local _ <close> = fs.switch_sync()
    return cr.compile(filename):string()
end

local filefactory = fileinterface.factory { preopen = preopen }

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

local effect_viewid<const> = viewidmgr.get "effect_view"
local efk_cb_handle, efk_ctx
function efk_sys:init()
    init_fx_files()
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

    assetmgr.set_efkobj(efk_ctx)
end

function efk_sys:exit()
    efk.shutdown(efk_ctx)
end

function efk_sys:entity_init()
    for e in w:select "INIT efk:update" do
        e.efk = {
            handle = assetmgr.resource(e.efk).handle,
            speed = 1.0,
            loop = false,
            visible = true,
        }
    end
end

function efk_sys:entity_remove()
    for e in w:select "REMOVED efk:in" do
        if e.efk.play_handle then
            efk_ctx:stop(e.efk.play_handle)
        end
        -- efk_ctx:destroy(e.efk.play_handle)
        e.efk.play_handle = nil
    end
end

local mq_vr_mb = world:sub{"viewrect_changed", "main_queue"}
local camera_changed = world:sub{"main_queue", "camera_changed"}
local camera_frustum_mb

local function update_framebuffer_texutre()
    local eq = w:first("efk_queue render_target:in")
    local fbidx = eq.render_target.fb_idx
    local fb = fbmgr.get(fbidx)
    efk_cb_handle.background = fb[1].handle

    local mq = w:first("main_queue camera_ref:in")
    local ce <close> = w:entity(mq.camera_ref, "camera:in")
    local projmat = ce.camera.projmat
    local col3, col4 = math3d.index(projmat, 3, 4)
    local m33, m34 = math3d.index(col3, 3, 4)
    local m43, m44 = math3d.index(col4, 3, 4)
    efk_cb_handle.depth = {
        handle = fbmgr.get_depth(fbidx).handle,
        1.0, --depth buffer scale
        0.0, --depth buffer offset
        m33, m34,
        m43, m44,
    }
end

function efk_sys:init_world()
    local mq = w:first("main_queue render_target:in camera_ref:in")
    camera_frustum_mb = world:sub{"camera_changed", mq.cameraref, "frustum"}
    local vp = world.args.viewport
    ecs.create_entity{
        policy = {
            "ant.general|name",
            "ant.efk|efk_queue",
            "ant.render|watch_screen_buffer",
        },
        data = {
            efk_queue = true,
            render_target = {
                view_rect = {x=vp.x, y=vp.y, w=vp.w, h=vp.h},
                viewid = effect_viewid,
                fb_idx = mq.render_target.fb_idx,
                view_mode = "s",
                clear_state = {
                    clear = "",
                },
            },
            queue_name = "efk_queue",
            watch_screen_buffer = true,
            name = "efk_queue",
        }
    }

    --let it init
    world:pub{"camera_changed", mq.cameraref, "frustum"}
end

local vp_changed_mb = world:sub{"world_viewport_changed"}
function efk_sys:camera_usage()
    -- fix effect viewport bug
    -- for _, vp in vp_changed_mb:unpack() do
    --     irq.set_view_rect("efk_queue", vp)
    -- end

    for _, _, cameraref in camera_changed:unpack() do
        camera_frustum_mb = world:sub{"camera_changed", cameraref, "frustum"}
        update_framebuffer_texutre()
    end

    for _ in camera_frustum_mb:each() do
        update_framebuffer_texutre()
    end

    for _ in mq_vr_mb:each() do
        update_framebuffer_texutre()
    end
end

function efk_sys:follow_transform_updated()
    for v in w:select "efk:in scene:in scene_changed?in" do
        local efk = v.efk
        if efk.play_handle then
            if not efk_ctx:is_alive(efk.play_handle) then
                if efk.loop then
                    efk.play_handle = efk_ctx:play(efk.handle, math3d.value_ptr(v.scene.worldmat), efk.speed)
                else
                    efk.play_handle = nil
                end
            elseif v.scene_changed then
                efk_ctx:update_transform(efk.play_handle, math3d.value_ptr(v.scene.worldmat))
            end
        else
            if efk.visible then
                if efk.do_play or efk.do_settime then
                    efk.play_handle = efk_ctx:play(efk.handle, math3d.value_ptr(v.scene.worldmat), efk.speed)
                end
                if efk.do_play then
                    efk.do_play = nil
                elseif efk.do_settime then
                    efk_ctx:set_time(efk.play_handle, efk.do_settime)
                    efk.do_settime = nil
                end
            end
        end
    end
end

--TODO: need remove, should put it on the ltask
function efk_sys:render_submit()
    local mq = w:first("main_queue camera_ref:in")
    local ce <close> = w:entity(mq.camera_ref, "camera:in")
    local camera = ce.camera
    efk_ctx:render(math3d.value_ptr(camera.viewmat), math3d.value_ptr(camera.projmat), itimer.delta())
end

local iefk = ecs.interface "iefk"

function iefk.create(filename, config)
    config = config or {
        play_on_create = false,
        loop = false,
        speed = 1.0,
        scene = {}
    }
    local template = {
        policy = {
            "ant.general|name",
            "ant.scene|scene_object",
            "ant.efk|efk",
            "ant.general|tag"
        },
        data = {
            name = "root",
            tag = {"effect"},
            scene = config.scene,
            efk = filename,
            on_ready = function (e)
                w:sync("efk:in", e)
                if config.play_on_create then
                    iefk.play(e)
                end
                iefk.set_loop(e, config.loop or false)
                iefk.set_speed(e, config.speed or 1.0)
            end
        },
    }
    return ecs.create_entity(template)
end

function iefk.preload(textures)
    for _, texture in ipairs(textures) do
        TEXTURES[texture] = assetmgr.resource(texture).id
    end
end

function iefk.play(e)
    w:extend(e, "efk:in")
    iefk.stop(e)
    e.efk.do_play = true
end

function iefk.pause(e, b)
    w:extend(e, "efk:in")
    if e.efk.play_handle then
        efk_ctx:pause(e.efk.play_handle, b)
    end
end

function iefk.set_time(e, t)
    w:extend(e, "efk:in")
    if e.efk.do_settime then
        return
    end
    if e.efk.play_handle then
        efk_ctx:set_time(e.efk.play_handle, t)
    else
        e.efk.do_settime = t
    end
end

function iefk.set_speed(e, s)
    w:extend(e, "efk:in")
    e.efk.speed = s
    if e.efk.play_handle then
        efk_ctx:set_speed(e.efk.play_handle, s)
    end
end

function iefk.set_visible(e, b)
    w:extend(e, "efk:in")
    e.efk.visible = b
    if e.efk.play_handle then
        efk_ctx:set_visible(e.efk.play_handle, b)
    end
end

function iefk.set_loop(e, b)
    w:extend(e, "efk:in")
    e.efk.loop = b
end

function iefk.destroy(e)
    w:extend(e, "efk:in")
    efk_ctx:destroy(e.efk.play_handle)
    e.efk.play_handle = nil
end

function iefk.stop(e, delay)
    w:extend(e, "efk:in")
    if e.efk.play_handle then
        efk_ctx:stop(e.efk.play_handle, delay)
        e.efk.play_handle = nil
    end
end

function iefk.is_playing(e)
    w:extend(e, "efk:in")
    return e.efk.play_handle ~= nil
end