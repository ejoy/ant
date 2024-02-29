local ecs   = ...
local world = ecs.world
local w     = world.w

local math3d    = require "math3d"
local fs        = require "filesystem"
local lefk      = require "efk"
local efkasset  = require "asset"

local renderpkg = import_package "ant.render"
local fbmgr     = renderpkg.fbmgr
local assetmgr  = import_package "ant.asset"
local iexposure = ecs.require "ant.camera|exposure"
local hwi       = import_package "ant.hwi"
local mc        = import_package "ant.math".constant
local aio       = import_package "ant.io"

local Q         = world:clibs "render.queue"

local itimer    = ecs.require "ant.timer|timer_system"
local ivs       = ecs.require "ant.render|visible_state"
local queuemgr  = ecs.require "ant.render|queue_mgr"
local ilight    = ecs.require "ant.render|light.light"
local iviewport = ecs.require "ant.render|viewport.state"
local iom       = ecs.require "ant.objcontroller|obj_motion"

local efk_sys   = ecs.system "efk_system"
local RC        = world:clibs "render.cache"

local effect_viewid <const> = hwi.viewid_get "effect_view"

local ltask = require "ltask"
local ServiceEfkUpdate
local ServiceBgfxEvent <const> = ltask.queryservice "ant.hwi|event"

local EFKCTX
local EFKCTX_HANDLE

local HANDLE_MT = {
    update_transform = function(self, mat)
        EFKCTX:update_transform(self.handle, math3d.serialize(mat))
    end,
    update_transforms = function(num, data)
        EFKCTX:update_transforms(num, data)
    end,
}

for _, n in ipairs{"play", "is_alive", "set_stop", "set_time", "pause", "set_speed", "set_visible"} do
    HANDLE_MT[n] = function (self, ...)
        return EFKCTX[n](EFKCTX, self.handle, ...)
    end
end

local EFKFILES = {}

local function release_efks(force)
    for efkname, e in pairs(EFKFILES) do
        if 0 == e.count or force then
            if force then
                log.info("Force destory efk file:", efkname, ", ref count: ", e.count)
            else
                log.info("Destroy efk file:", efkname)
            end

            EFKFILES[efkname] = nil
            e.obj:release()
            e.obj = nil
        end
    end
end

local function shutdown()
    release_efks(true)
    if EFKCTX then
        lefk.shutdown(EFKCTX)
        EFKCTX = nil
        EFKCTX_HANDLE = nil
    end

    if next(EFKFILES) then
        error("efk file is not removed before 'shutdown'")
    end
end

local check_release_efks; do
    local last = ltask.walltime()

    local checktime<const> = 1000
    function check_release_efks()
        local now = ltask.walltime()
        local d = now - last
        if d >= checktime then
            last = now
            release_efks()
        end
    end
end

local function destroy_efk(filename, handle)
    local info = EFKFILES[filename] or error ("Invalid efk file: " .. filename)
    assert(info.count > 0)
    info.count = info.count - 1
    EFKCTX:destroy(handle)
end

local function createPlayHandle(efk_handle, speed, startframe, fadeout, worldmat)
    local h = setmetatable({
        alive       = true,
        handle      = efk_handle,
    }, {__index     = HANDLE_MT})
    h:play(speed, startframe, fadeout)
    if worldmat then
        h:update_transform(worldmat)
    end
    return h
end

local function init_efk()
    EFKCTX = efkasset.init_efk_ctx(4096, effect_viewid, assetmgr.default_textureid "SAMPLER2D")
    EFKCTX_HANDLE = EFKCTX
end

function efk_sys:init()
    queuemgr.register_queue "efk_queue"
    RC.set_queue_type("efk_queue", queuemgr.queue_index "efk_queue")

    ServiceEfkUpdate = ltask.spawn "ant.efk|update"

    init_efk()
end

local function cleanup_efk(efk)
    if efk.play_handle then
        efk.play_handle:set_stop()
        efk.play_handle = nil
    end

    if efk.handle then
        destroy_efk(efk.path, efk.handle)
        efk.path = nil
        efk.handle = nil
    end
end

function efk_sys:exit()
    ltask.call(ServiceEfkUpdate, "quit")
    shutdown()
end

local function create_efk(filename)
    local info = EFKFILES[filename]
    if not info then
        log.info("Create efk file:", filename)
        local c = aio.readall(filename)
        info = {
            obj = EFKCTX:new(c, fs.path(filename):parent_path():string()),
            count = 0,
        }
        EFKFILES[filename] = info
    end
    info.count = info.count + 1
    return EFKCTX:create(info.obj)
end

local function init_efk_component(efk)
    efk.speed       = efk.speed or 1.0
    efk.startframe  = efk.startframe or 0
    efk.fadeout     = efk.fadeout or false
    efk.handle      = create_efk(efk.path)
    efk.play_handle = createPlayHandle(efk.handle, efk.speed, efk.startframe, efk.fadeout)
end

local function init_efk_object(eo)
    eo.visible_idx = Q.alloc()
end

function efk_sys:component_init()
    for e in w:select "INIT efk_object:update efk:in" do
        init_efk_component(e.efk)
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

function efk_sys:frame_start()
    EFKCTX = EFKCTX_HANDLE
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

    efkasset.update_cb_data(fb[1].handle, depth)
end

local need_update_framebuffer

local effect_viewid<const> = hwi.viewid_get "effect_view"

local function create_fb()
    local tmq = w:first "tonemapping_queue render_target:in"
    local mq = w:first "main_queue render_target:in"
    return fbmgr.create(
        {rbidx = fbmgr.get(tmq.render_target.fb_idx)[1].rbidx},
        {rbidx = fbmgr.get(mq.render_target.fb_idx)[2].rbidx})
end

function efk_sys:init_world()
    local vr = iviewport.viewrect
    world:create_entity{
        policy = {
            "ant.efk|efk_queue",
            "ant.render|watch_screen_buffer",
        },
        data = {
            visible = true,
            submit_queue = true,
            efk_queue = true,
            render_target = {
                view_rect = {x=vr.x, y=vr.y, w=vr.w, h=vr.h},
                viewid = effect_viewid,
                fb_idx = create_fb(),
                view_mode = "s",
                clear_state = {clear = "",},
            },
            queue_name = "efk_queue",
            watch_screen_buffer = true,
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
    EFKCTX:setstate(math3d.serialize(camera.viewmat), math3d.serialize(camera.infprojmat), itimer.delta())
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

function efk_sys:follow_scene_update()
	for e in w:select "scene_changed scene:in efk:in efk_object:update" do
		e.efk_object.worldmat = e.scene.worldmat
	end

    for e in w:select "visible_state_changed efk_object:update efk:in visible_state:in" do
        local visible = e.visible_state.main_queue and true or false
        Q.set(e.efk_object.visible_idx, queuemgr.queue_index "efk_queue", visible)
        e.efk.play_handle:set_visible(visible)
    end

    local dl        = w:first "directional_light light:in scene:in"
    if dl then
        local direction, color = get_light_direction(dl), get_light_color(dl)
        EFKCTX:set_light_direction(direction)
        EFKCTX:set_light_color(color)
    end

    for e in w:select "efk_visible efk:in scene:in" do
        local ph = e.efk.play_handle
        ph:update_transform(e.scene.worldmat)
    end
end

local function efk_render()
    check_release_efks()
    efkasset.check_load_textures()
    EFKCTX = nil
    ltask.send(ServiceBgfxEvent, "set", "efk", EFKCTX_HANDLE:handle(), EFKCTX_HANDLE.render)
end

local function update_hitch_efks()
    local num = w:count "efk_hitch"
    if num > 0 then
        local data = w:swap("efk_hitch", "efk_hitch_backbuffer")
        EFKCTX:update_transforms(num, data)
    end
end

function efk_sys:render_postprocess()
    update_hitch_efks()
    efk_render()
end

local iefk = {}
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
    efk.play_handle:play(efk.speed, efk.startframe, efk.fadeout)
    iefk.set_visible(e, true)
end

function iefk.pause(e, b)
    e.efk.play_handle:pause(b)
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
