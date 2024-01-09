local ecs   = ...
local world = ecs.world
local w     = world.w

local ltask     = require "ltask"
local EFK_SERVER


local math3d    = require "math3d"
local renderpkg = import_package "ant.render"
local fbmgr     = renderpkg.fbmgr
local assetmgr  = import_package "ant.asset"
local iexposure = ecs.require "ant.camera|exposure"
local hwi       = import_package "ant.hwi"
local mc        = import_package "ant.math".constant

local bgfxmainS = ltask.queryservice "ant.hwi|bgfx"

local Q         = world:clibs "render.queue"

local itimer    = ecs.require "ant.timer|timer_system"
local ivs       = ecs.require "ant.render|visible_state"
local qm        = ecs.require "ant.render|queue_mgr"
local ilight    = ecs.require "ant.render|light.light"
local iviewport = ecs.require "ant.render|viewport.state"
local iom       = ecs.require "ant.objcontroller|obj_motion"
local efk_sys = ecs.system "efk_system"
local iefk = {}

local handle_mt = {
    realive = function (self, speed, startframe, fadeout)
        ltask.call(EFK_SERVER, "play", self.handle, speed, startframe, fadeout)
    end,
    is_alive = function(self)
        ltask.fork(function ()
            self.alive = ltask.call(EFK_SERVER, "is_alive", self.handle)
        end)
        return self.alive
    end,
    set_stop = function(self, delay)
        ltask.send(EFK_SERVER, "set_stop", self.handle, delay)
    end,

    set_time = function(self, time)
        ltask.send(EFK_SERVER, "set_time", self.handle, time)
    end,
    set_pause = function(self, p)
        assert(p ~= nil)
        ltask.send(EFK_SERVER, "set_pause", self.handle, p)
    end,
    
    set_speed = function(self, speed)
        assert(speed ~= nil)
        ltask.send(EFK_SERVER, "set_speed", self.handle, speed)
    end,
    
    set_visible = function(self, v)
        ltask.send(EFK_SERVER, "set_visible", self.handle, v)
    end,

    update_transform = function(self, mat)
        ltask.send(EFK_SERVER, "update_transform", self.handle, math3d.serialize(mat))
    end,
}

local function createPlayHandle(efk_handle, speed, startframe, fadeout, worldmat)
    ltask.call(EFK_SERVER, "play", efk_handle, speed, startframe, fadeout)
    local h = setmetatable({
        alive       = true,
        handle      = efk_handle,
    }, {__index = handle_mt})
    if worldmat then
        h:update_transform(worldmat)
    end
    return h
end

function efk_sys:init()
    EFK_SERVER = ltask.spawn "ant.efk|efk"
    ltask.call(EFK_SERVER, "init")
    ltask.call(EFK_SERVER, "init_default_tex2d", assetmgr.default_textureid "SAMPLER2D")
end

local function cleanup_efk(efk)
    if efk.play_handle then
        efk.play_handle:set_stop()
        efk.play_handle = nil
    end

    if efk.handle then
        ltask.send(EFK_SERVER, "destroy", efk.path, efk.handle)
        efk.path = nil
        efk.handle = nil
    end
end

function efk_sys:exit()
    for e in w:select "efk:in eid:in" do
        log.warn(("'efk_system' is exiting, but efk entity:%d is not REMOVED"):format(e.eid))
        cleanup_efk(e.efk)
    end

    ltask.call(EFK_SERVER, "exit")
    ltask.call(EFK_SERVER, "quit")
end

local function init_efk(efk)
    efk.handle = ltask.call(EFK_SERVER, "create", efk.path)
    efk.speed = efk.speed or 1.0
    efk.startframe = efk.startframe or 0
    efk.fadeout = efk.fadeout or false
    efk.play_handle = createPlayHandle(efk.handle, efk.speed, efk.startframe, efk.fadeout)
end

local function init_efk_object(eo)
    eo.visible_idx = Q.alloc()
end

function efk_sys:component_init()
    for e in w:select "INIT efk_object:update efk:in" do
        init_efk(e.efk)
        init_efk_object(e.efk_object)
    end
end

function efk_sys:entity_init()
    for e in w:select "INIT scene:in efk:in efk_object:update view_visible?in efk_visible?out" do
        local eo            = e.efk_object
        eo.handle           = e.efk.handle
        eo.worldmat         = e.scene.worldmat
        e.efk_visible       = e.view_visible
    end
end

local function cleanup_efk_object(eo)
    Q.dealloc(eo.visible_idx)
end

function efk_sys:entity_remove()
    for e in w:select "REMOVED efk:in efk_object:in" do
        cleanup_efk(e.efk)
        cleanup_efk_object(e.efk_object)
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
    local main_fb = fbmgr.get(mq.render_target.fb_idx)
    local vr = iviewport.viewrect
    world:create_entity{
        policy = {
            "ant.efk|efk_queue",
            "ant.render|watch_screen_buffer",
        },
        data = {
            efk_queue = true,
            render_target = {
                view_rect = {x=vr.x, y=vr.y, w=vr.w, h=vr.h},
                viewid = effect_viewid,
                fb_idx = fbmgr.create(table.unpack(main_fb)),
                view_mode = "s",
                clear_state = {
                    clear = "",
                },
            },
            queue_name = "efk_queue",
            watch_screen_buffer = true,
            on_ready = function(e)
                local tmq = w:first "tonemapping_queue render_target:in"
                w:extend(e, "render_target:update")
                local fbidx = e.render_target.fb_idx
                local tm_rb = fbmgr.get(tmq.render_target.fb_idx)[1]
                local depth_rb = fbmgr.get(mq.render_target.fb_idx)[2]
                local depth_rb_table = fbmgr.get_rb(depth_rb.rbidx)
                local ww, hh = depth_rb_table.w, depth_rb_table.h
                fbmgr.resize_rb(tm_rb.rbidx, ww, hh)
                local fb = {
                    {rbidx = tm_rb.rbidx},
                    {rbidx = depth_rb.rbidx}
                }
                fbmgr.recreate(fbidx, fb)
                need_update_framebuffer = true
            end
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
        update_framebuffer_texutre(camera.infprojmat)
        need_update_framebuffer = nil
    end
    ltask.call(bgfxmainS, "update_world_camera", math3d.serialize(camera.viewmat), math3d.serialize(camera.infprojmat), itimer.delta())
end

function efk_sys:follow_scene_update()
	for e in w:select "scene_changed scene:in efk:in efk_object:update" do
		e.efk_object.worldmat = e.scene.worldmat
	end

    for e in w:select "visible_state_changed efk_object:update efk:in visible_state:in" do
        local visible = e.visible_state.main_queue
        Q.set(e.efk_object.visible_idx, qm.queue_index "main_queue", visible)
        e.efk.play_handle:set_visible(visible)
    end
end

local function normalize_color(color)
    local nc = math3d.normalize(color)
    return math3d.set_index(nc, 4, 1.0)
end

local function get_light_color(dl)
    local mq = w:first "main_queue camera_ref:in"
    local camera <close> = world:entity(mq.camera_ref)
    local ev = iexposure.exposure(camera)
    local intensity = ilight.intensity(dl) * ev
    local color = intensity == 0 and mc.ZERO_PT or normalize_color(math3d.mul(intensity, math3d.vector(ilight.color(dl))))
    
    local r, g, b, a = math3d.index(math3d.floor(math3d.mul(255, color)), 1, 2, 3, 4)
    return string.pack("<BBBB", r, g, b, a)
end

local function get_light_direction(dl)
    return math3d.serialize(iom.get_direction(dl))
end

function efk_sys:render_submit()
    local dl        = w:first "directional_light light:in scene:in"
    if dl then
        local direction, color = get_light_direction(dl), get_light_color(dl)
        ltask.send(EFK_SERVER, "set_light_direction", direction)
        ltask.send(EFK_SERVER, "set_light_color", color) 
    end
    for e in w:select "efk_visible efk:in scene:in" do
        --update_transform will check efk is alive and visible or not
        local ph = e.efk.play_handle
        ph:update_transform(e.scene.worldmat)
    end
end

function efk_sys:render_postprocess()
    local num = w:count "efk_hitch"
    if num > 0 then
        local data = w:swap("efk_hitch", "efk_hitch_backbuffer")
        ltask.send(EFK_SERVER, "update_transforms", num, data)
    end
end

function iefk.create(filename, config)
    return world:create_entity {
        group = config.group,
        policy = {
            "ant.scene|scene_object",
            "ant.efk|efk",
        },
        data = {
            scene = config.scene or {},
            efk = {
                path        = filename,
                speed       = config.speed or 1.0,
                time        = config.time or 0.0,
                startframe  = config.startframe or 0,
            },
            visible_state = config.visible_state,
        },
    }
end

function iefk.play(e)
    local efk = e.efk
    if efk then
        local ph = efk.play_handle
        ph:realive(efk.speed, efk.startframe, efk.fadeout)
        ph:set_visible(true)
    end
    iefk.set_visible(e, true)
end

function iefk.pause(e, b)
    e.efk.play_handle:set_pause(b)
end

function iefk.set_time(e, t)
    e.efk.play_handle:set_time(t)
end

function iefk.set_speed(e, s)
    e.efk.play_handle:set_speed(s)
end

function iefk.set_visible(e, b)
    e.efk.play_handle:set_visible(b)
    ivs.set_state(e, "main_queue", b)
end

function iefk.stop(e, delay)
    e.efk.play_handle:set_stop(delay)
end

function iefk.is_playing(e)
    return e.efk.play_handle:is_alive()
end

return iefk
