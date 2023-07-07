local ecs   = ...
local world = ecs.world
local w     = world.w

local ltask     = require "ltask"
local EFK_SERVER


local math3d    = require "math3d"
local renderpkg = import_package "ant.render"
local viewidmgr = renderpkg.viewidmgr
local fbmgr     = renderpkg.fbmgr
local assetmgr  = import_package "ant.asset"

local bgfxmainS = ltask.queryservice "ant.render|bgfx_main"

local itimer    = ecs.import.interface "ant.timer|itimer"

local PH

local efk_sys = ecs.system "efk_system"
local iefk = ecs.interface "iefk"

local function init_fx_files()
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
        local filename = ("/pkg/ant.efk/materials/%s.material"):format(name)
        local r = assetmgr.load_fx(filename)
        FxFiles[name] = r.fx
    end
    return FxFiles
end

function efk_sys:init()
    EFK_SERVER = ltask.uniqueservice "ant.efk|efk"
    ltask.call(EFK_SERVER, "init", init_fx_files())
    PH = require "playhandle"
end

function efk_sys:exit()
end

function efk_sys:component_init()
    for e in w:select "INIT efk:in eid:in" do
        e.efk.handle = assetmgr.resource(e.efk.path).handle
        e.efk.speed = e.efk.speed or 1.0
        e.efk.loop = e.efk.loop or false
        e.efk.visible = e.efk.visible or true
        if e.efk.auto_play then
            world:pub {"playeffect", e.eid}
        end
    end
end

local playevent = world:sub {"playeffect"}
function efk_sys:entity_ready()
    for _, eid in playevent:unpack() do
        iefk.play(eid)
    end
end

function efk_sys:entity_remove()
    for e in w:select "REMOVED efk:in" do
        if e.efk.play_handle then
            e.efk.play_handle:set_stop()
        end
        e.efk.play_handle = nil
    end
end

local mq_vr_mb = world:sub{"view_rect_changed", "main_queue"}
local mq_camera_changed = world:sub{"main_queue", "camera_changed"}

local function update_framebuffer_texutre(projmat)
    local eq = w:first "efk_queue render_target:in"
    local fbidx = eq.render_target.fb_idx
    local fb = fbmgr.get(fbidx)

    local c3, c4 = math3d.index(projmat, 3, 4)
    local m33, m34 = math3d.index(c3, 3, 4)
    local m43, m44 = math3d.index(c4, 3, 4)
    local depth = {
        handle = fbmgr.get_depth(fbidx).handle,
        1.0, --depth buffer scale
        0.0, --depth buffer offset
        m33, m34,
        m43, m44,
    }

    ltask.call(EFK_SERVER, "update_cb_data", fb[1].handle, depth)
end

local need_update_framebuffer

local effect_viewid<const> = viewidmgr.get "effect_view"

function efk_sys:init_world()
    local mq = w:first("main_queue render_target:in camera_ref:in")
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
    need_update_framebuffer = true
end

function efk_sys:camera_usage()
    for _ in mq_camera_changed:each() do
        need_update_framebuffer = true
    end

    for _ in mq_vr_mb:each() do
        need_update_framebuffer = true
    end

    if not need_update_framebuffer then
        local mq = w:first "main_queue camera_ref:in"
        local ce = w:entity(mq.camera_ref, "camera_changed?in")
        need_update_framebuffer = ce.camera_changed
    end

    local mq = w:first "main_queue camera_ref:in"
    local ce <close> = w:entity(mq.camera_ref, "camera:in camera_changed?in scene_changed?in")
    local camera = ce.camera

    if need_update_framebuffer then
        update_framebuffer_texutre(camera.projmat)
        need_update_framebuffer = nil
    end

    ltask.call(bgfxmainS, "update_world_camera", math3d.serialize(camera.viewmat), math3d.serialize(camera.projmat), itimer.delta())
end

function efk_sys:follow_transform_updated()
    for v in w:select "view_visible efk:in scene:in scene_changed?in" do
        local efk = v.efk
        if efk.play_handle_hitchs then
            local new_handles = {}
            local del_handles = {}
            for eid, handle in pairs(efk.play_handle_hitchs) do
                if not handle:is_alive() then
                    if efk.loop then
                        local e <close> = w:entity(eid, "scene:in")
                        local wm = math3d.mul(v.scene.worldmat, e.scene.worldmat)
                        new_handles[eid] = PH.create(efk.handle, wm, efk.speed)
                    else
                        del_handles[#del_handles + 1] = eid
                    end
                end
            end
            for eid, handle in pairs(new_handles) do
                efk.play_handle_hitchs[eid] = handle
            end
            for _, eid in ipairs(del_handles) do
                efk.play_handle_hitchs[eid] = nil
            end
        end
        
        if efk.play_handle then
            if not efk.play_handle:is_alive() then
                if efk.loop then
                    efk.play_handle = PH.create(efk.handle, v.scene.worldmat, efk.speed)
                else
                    efk.play_handle = nil
                end
            elseif v.scene_changed then
                efk.play_handle:set_transform(v.scene.worldmat)
            end
        else
            if efk.visible then
                if efk.do_play or efk.do_settime then
                    if efk.hitchs and next(efk.hitchs) then
                        if not efk.play_handle_hitchs then
                            efk.play_handle_hitchs = {}
                        end
                        for eid, _ in pairs(efk.hitchs) do
                            local e <close> = w:entity(eid, "scene:in")
                            local wm = math3d.mul(e.scene.worldmat, v.scene.worldmat)
                            efk.play_handle_hitchs[eid] = PH.create(efk.handle, wm, efk.speed)
                        end
                    else
                        efk.play_handle = PH.create(efk.handle, v.scene.worldmat, efk.speed)
                    end
                end
                if efk.do_play then
                    efk.do_play = nil
                elseif efk.do_settime then
                    efk.play_handle:set_time(efk.do_settime)
                    efk.do_settime = nil
                end
            end
        end
    end
end

function iefk.create(filename, config)
    config = config or {}
    local cfg = {
        scene = config.scene or {},
        auto_play = config.auto_play or false,
        loop = config.loop or false,
        speed = config.speed or 1.0,
        visible = config.visible or true,
        hitchs = config.hitchs
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
            scene = cfg.scene,
            efk = {
                path = filename,
                auto_play = cfg.auto_play,
                loop = cfg.loop,
                speed = cfg.speed,
                visible = cfg.visible,
                hitchs = config.hitchs
            },
            -- on_ready = function (e)
            --     w:extend(e, "efk:in")
            --     if cfg.auto_play then
            --         iefk.play(e)
            --     end
            -- end
        },
    }
    return config.group_id and ecs.group(config.group_id):create_entity(template) or ecs.create_entity(template)
end

function iefk.preload(textures)
    for _, texture in ipairs(textures) do
        ltask.call(EFK_SERVER, "preload_texture", texture, assetmgr.resource(texture).id)
    end
end

local function do_play(eid)
    local e <close> = w:entity(eid, "efk?in")
    if not e.efk then return end
    iefk.stop(eid)
    e.efk.do_play = true
end

function iefk.play(efk)
    if type(efk) == "table" then
		local entitys = efk.tag["*"]
		for _, eid in ipairs(entitys) do
			do_play(eid)
		end
    else
        do_play(efk)
    end
end

function iefk.pause(eid, b)
    local e <close> = w:entity(eid, "efk?in")
    if e.efk and e.efk.play_handle then
        e.efk.play_handle:set_pause(b)
    end
end

function iefk.set_time(eid, t)
    local e <close> = w:entity(eid, "efk?in")
    if not e.efk then return end
    if e.efk.do_settime then
        return
    end
    if e.efk.play_handle then
        e.efk.play_handle:set_time(t)
    else
        e.efk.do_settime = t
    end
end

function iefk.set_speed(eid, s)
    local e <close> = w:entity(eid, "efk:in")
    e.efk.speed = s
    if e.efk.play_handle then
        e.efk.play_handle:set_speed(s)
    end
end

function iefk.set_visible(eid, b)
    local e <close> = w:entity(eid, "efk?in")
    if not e.efk then return end
    e.efk.visible = b
    if e.efk.play_handle then
        e.efk.play_handle:set_visible(b)
    end
end

function iefk.set_loop(eid, b)
    local e <close> = w:entity(eid, "efk?in")
    if not e.efk then return end
    e.efk.loop = b
end

function iefk.destroy(eid)
    local e <close> = w:entity(eid, "efk?in")
    if not e.efk then return end
    e.efk.play_handle = nil
end

local function do_stop(eid, delay)
    local e <close> = w:entity(eid, "efk?in")
    if e.efk and e.efk.play_handle then
        e.efk.play_handle:set_stop(delay)
        e.efk.play_handle = nil
    end
end

function iefk.stop(efk, delay)
    if type(efk) == "table" then
		local entitys = efk.tag["*"]
		for _, eid in ipairs(entitys) do
			do_stop(eid, delay)
		end
    else
        do_stop(efk, delay)
    end
end

function iefk.is_playing(eid)
    local e <close> = w:entity(eid, "efk?in")
    return e.efk and e.efk.play_handle ~= nil
end