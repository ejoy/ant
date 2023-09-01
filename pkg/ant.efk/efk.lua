local ecs   = ...
local world = ecs.world
local w     = world.w

local ltask     = require "ltask"
local EFK_SERVER


local math3d    = require "math3d"
local renderpkg = import_package "ant.render"
local fbmgr     = renderpkg.fbmgr
local assetmgr  = import_package "ant.asset"

local hwi       = import_package "ant.hwi"

local bgfxmainS = ltask.queryservice "ant.hwi|bgfx_main"

local itimer    = ecs.require "ant.timer|timer_system"
local qm        = ecs.require "ant.render|queue_mgr"
local PH

local efk_sys = ecs.system "efk_system"
local iefk = {}

local MAX_EFK_HITCH<const> = 256

function efk_sys:init()
    EFK_SERVER = ltask.uniqueservice "ant.efk|efk"
    ltask.call(EFK_SERVER, "init")
    PH = ecs.require "playhandle"

    for _=1, MAX_EFK_HITCH do
        w:temporary("efk_hitch_tag", "efk_hitch")
    end
end

local function cleanup_efk(efk)
    if efk.play_handle then
        efk.play_handle:set_stop()
        efk.play_handle = nil
    end

    if efk.handle then
        ltask.send(EFK_SERVER, "destroy", assert(efk.path))
        efk.path = nil
        efk.handle = nil
    end
end

function efk_sys:exit()
    for e in w:select "efk:in eid:in name?in" do
        log.warn(("'efk_system' is exiting, but efk entity:%d, %s is not REMOVED"):format(e.eid, e.name or ""))
        cleanup_efk(e.efk)
    end

    ltask.call(EFK_SERVER, "exit")
end

function efk_sys:component_init()
    for e in w:select "INIT efk:in view_visible?in" do
        local efk = e.efk
        efk.handle = ltask.call(EFK_SERVER, "create", efk.path)
        efk.speed = efk.speed or 1.0
        efk.play_handle = PH.create(efk.handle, efk.speed)

        efk.play_handle:set_visible(e.view_visible or efk.auto_play)
    end
end

function efk_sys:entity_init()
    for e in w:select "INIT scene:in efk:in efk_object:update" do
        local eo = e.efk_object

        eo.handle           = e.efk.handle
        eo.worldmat         = e.scene.worldmat
        eo.visible_masks    = qm.queue_mask "main_queue"
    end
end

function efk_sys:entity_remove()
    for e in w:select "REMOVED efk:in" do
        cleanup_efk(e.efk)
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

local effect_viewid<const> = hwi.viewid_get "effect_view"

function efk_sys:init_world()
    local mq = w:first("main_queue render_target:in camera_ref:in")
    local vp = world.args.viewport
    world:create_entity{
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
        local ce = world:entity(mq.camera_ref, "camera_changed?in")
        need_update_framebuffer = ce.camera_changed
    end

    local mq = w:first "main_queue camera_ref:in"
    local ce <close> = world:entity(mq.camera_ref, "camera:in camera_changed?in scene_changed?in")
    local camera = ce.camera

    if need_update_framebuffer then
        update_framebuffer_texutre(camera.projmat)
        need_update_framebuffer = nil
    end

    ltask.call(bgfxmainS, "update_world_camera", math3d.serialize(camera.viewmat), math3d.serialize(camera.projmat), itimer.delta())
end

function efk_sys:scene_update()
	for e in w:select "scene_changed scene:in efk:in efk_object:update" do
		e.efk_object.worldmat = e.scene.worldmat
	end
end

local function iter_group_hitch_DEBUG_ONLY()
    local mq_mask = qm.queue_mask "main_queue"
    local groups = setmetatable({}, {__index=function (tt, idx) local t = {}; tt[idx] = t;return t end})
    for e in w:select "view_visible hitch:in scene:in" do
        local h = e.hitch
        if 0 == (h.cull_masks & mq_mask) then
            local s = e.scene
            if h.group ~= 0 then
                local mats = groups[h.group]
                mats[#mats+1] = s.worldmat
            end
        end
	end

    for gid, mats in pairs(groups) do
        world:group_enable_tag("hitch_tag", gid)
        world:group_flush "hitch_tag"

        for e in w:select "hitch_tag efk:in scene:in" do
            e.efk.play_handle:update_hitch_transforms(mats, e.scene.worldmat)
        end
    end
end

function efk_sys:render_submit()
    for e in w:select "efk:in view_visible scene:in" do
        --update_transform will check efk is alive and visible or not
        local ph = e.efk.play_handle
        ph:update_transform(e.scene.worldmat)
    end
end

function efk_sys:render_postprocess()
    --iter_group_hitch_DEBUG_ONLY()
    local handles, mats = {}, {}
    for e in w:select "efk_hitch:in" do
        local eh = e.efk_hitch
        handles[#handles+1] = eh.handle
        mats[#mats+1] = math3d.serialize(eh.hitchmat)
    end

    if #handles > 0 then
        ltask.send(EFK_SERVER, "update_hitch_transforms", handles, table.concat(mats, ""))
    end
end

function iefk.create(filename, config)
    config = config or {}
    assert(config.visible ~= nil, "Need define visible in 'config' filed")
    return world:create_entity {
        group = config.group,
        policy = {
            "ant.general|name",
            "ant.scene|scene_object",
            "ant.efk|efk",
        },
        data = {
            name = "root",
            scene = config.scene or {},
            efk = {
                path        = filename,
                auto_play   = config.auto_play or false,
                speed       = config.speed or 1.0,
            },
            view_visible    = config.visible,
        },
    }
end

function iefk.preload(textures)
    for _, texture in ipairs(textures) do
        ltask.call(EFK_SERVER, "preload_texture", texture, assetmgr.load_texture(texture))
    end
end

--TODO: need remove all the code checking 'efk' component is valid or not
function iefk.play(efk)
    local function realive(eid)
        local e <close> = world:entity(eid, "efk?in")
        local eefk = e.efk
        if eefk then
            eefk.play_handle:realive(eefk.speed)
        end
    end
    if type(efk) == "table" then
		local entitys = efk.tag["*"]
		for _, eid in ipairs(entitys) do
            realive(eid)
			iefk.set_visible(eid, true)
		end
    else
        realive(efk)
        iefk.set_visible(efk, true)
    end
end

function iefk.pause(eid, b)
    local e <close> = world:entity(eid, "efk?in")
    local efk = e.efk
    if efk then
        efk.play_handle:set_pause(b)
    end
end

function iefk.set_time(eid, t)
    local e <close> = world:entity(eid, "efk?in")
    local efk = e.efk
    if e.efk then
        efk.play_handle:set_time(t)
    end
end

function iefk.set_speed(eid, s)
    local e <close> = world:entity(eid, "efk?in")
    local efk = e.efk
    if efk then
        efk.play_handle:set_speed(s)
    end
end

function iefk.set_visible(eid, b)
    local e <close> = world:entity(eid, "efk?in")
    local efk = e.efk
    if efk then
        efk.play_handle:set_visible(b)

        -- no need to submit
        w:extend(e, "view_visible?out")
        e.view_visible = b
    end
end

local function do_stop(eid, delay)
    local e <close> = world:entity(eid, "efk?in")
    local efk = e.efk
    if efk then
        efk.play_handle:set_stop(delay)
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
    local e <close> = world:entity(eid, "efk?in")
    local efk = e.efk
    if efk then
        return efk.play_handle:is_alive()
    end
end

return iefk
