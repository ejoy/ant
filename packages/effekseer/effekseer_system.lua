local ecs = ...
local world = ecs.world
local w = world.w
-- local fbmgr         = require "framebuffer_mgr"
-- local viewidmgr     = require "viewid_mgr"

local assetmgr      = import_package "ant.asset"
local math3d        = require "math3d"
local effekseer     = require "effekseer"

local renderpkg     = import_package "ant.render"
local declmgr       = renderpkg.declmgr
local viewidmgr     = renderpkg.viewidmgr
local fbmgr         = renderpkg.fbmgr

local bgfx = require "bgfx"

local math3d_adapter = require "math3d.adapter"
effekseer.update_transform = math3d_adapter.matrix(effekseer.update_transform, 3, 1)

local effekseer_sys = ecs.system "effekseer_system"
local time_callback

local shader_type = {
    "unlit", "lit", "distortion", "ad_unlit", "ad_lit", "ad_distortion", "mtl"
}

function effekseer_sys:init()
    local path = "/pkg/ant.resources/shaders/effekseer/"
    local sprite_shader_defines = {}
    local model_shader_defines = {}
    for _, type in ipairs(shader_type) do
        local fs_path = path .. "fs_model_unlit.sc"
        local vs_path = path .. "vs_sprite_unlit.sc"
        if type == "ad_unlit" then
            fs_path = path .. "fs_ad_model_unlit.sc"
            vs_path = path .. "vs_ad_sprite_unlit.sc"
        end
        sprite_shader_defines[#sprite_shader_defines + 1] = {
            -- fs = path .. "fs_model_" .. type .. ".sc",
            -- vs = path .. "vs_sprite_" .. type .. ".sc",
            fs = fs_path,
            vs = vs_path,
            setting = {}
        }
    end
    for _, type in ipairs(shader_type) do
        local fs_path = path .. "fs_model_unlit.sc"
        local vs_path = path .. "vs_model_unlit.sc"
        if type == "ad_unlit" then
            fs_path = path .. "fs_ad_model_unlit.sc"
            vs_path = path .. "vs_ad_model_unlit.sc"
        end
        model_shader_defines[#model_shader_defines + 1] = {
            -- fs = path .. "fs_model_" .. type .. ".sc",
            -- vs = path .. "vs_model_" .. type .. ".sc",
            fs = fs_path,
            vs = vs_path,
            setting = {}
        }
    end
    local function create_shaders(def)
        local programs = {}
        for _, v in ipairs(def) do
            programs[#programs + 1] = assetmgr.load_fx(v)
        end
        return programs
    end
    
    effekseer.init {
        viewid = viewidmgr.get "effect_view",
        square_max_count = 8000,
        sprite_programs = create_shaders(sprite_shader_defines),
        model_programs = create_shaders(model_shader_defines),
        unlit_layout = declmgr.get "p3|c40niu|t20".handle,
        lit_layout = declmgr.get "p3|c40niu|n40niu|T40niu|t20|t21".handle,
        distortion_layout = declmgr.get "p3|c40niu|n40niu|T40niu|t20|t21".handle,
        ad_unlit_layout = declmgr.get "p3|c40niu|t20|t41|t42|t43".handle,
        ad_lit_layout = declmgr.get "p3|c40niu|n40niu|T40niu|t20|t21|t42|t43|t44".handle,
        ad_distortion_layout = declmgr.get "p3|c40niu|n40niu|T40niu|t20|t21|t42|t43|t44".handle,
        mtl_layout = declmgr.get "p3|c40niu|t20".handle,
        mtl1_layout = declmgr.get "p3|c40niu|n40niu|b40niu|t20|t21|t42".handle,
        mtl2_layout = declmgr.get "p3|c40niu|n40niu|b40niu|t20|t21|t42|t43".handle,
        model_layout = declmgr.get "p3|n3|b3|T3|t20|c40niu".handle
    }

    local fxloader = function(vspath, fspath)
        return assetmgr.load_fx { fs = fspath, vs = vspath, setting = {} }
    end
    effekseer.set_fxloader(fxloader)
    
    local filemgr = require "filemanager"
    -- filemgr.add("/pkg/ant.resources.binary/effekseer/Base")
    effekseer.set_path_converter(filemgr.realpath)
end

function effekseer_sys:entity_init()
    for e in w:select "INIT effekseer:in effect_instance:out" do
        if type(e.effekseer) == "string" then
            local eff_asset = assetmgr.resource(e.effekseer)
            e.effect_instance = {
                handle 		= effekseer.create(eff_asset.rawdata, eff_asset.filename),
                playid      = -1,
                speed 		= e.speed or 1.0,
                auto_play 	= e.auto_play or false,
                loop 		= e.loop or false
            }
        end
    end
end

local imgr = ecs.interface "filename_mgr"

function imgr.add_path(path)
    local filemgr = require "filemanager"
    filemgr.add(path)
end

local iplay = ecs.interface "effekseer_playback"

local function get_effect_instance(eid)
    w:sync("effect_instance?in", eid)
    return eid.effect_instance
end
function iplay.play(eid, loop)
    local instance = get_effect_instance(eid)
    --if effekseer.is_playing(instance.handle, instance.playid) then return end
    world:pub {"play_effect", instance, loop or false}
end

function iplay.destroy(eid)
    local instance = get_effect_instance(eid)
    effekseer.destroy(eid > 0 and instance.handle or eid)
end

function iplay.stop(eid)
    local instance = get_effect_instance(eid)
    effekseer.stop(instance.handle, instance.playid)
end

function iplay.is_playing(eid)
    local instance = get_effect_instance(eid)
    return effekseer.is_playing(instance.handle, instance.playid)
end

function iplay.pause(eid, b)
    local instance = get_effect_instance(eid)
    effekseer.pause(instance.handle, instance.playid, b)
end

function iplay.set_time(eid, second, should_exist)
    local instance = get_effect_instance(eid)
    local frame = math.floor(second * 60)
    local newid = effekseer.set_time(instance.handle, instance.playid, frame, should_exist)
    if instance.playid ~= newid then
        instance.playid = newid
    end
end

function iplay.set_speed(eid, speed)
    local instance = get_effect_instance(eid)
    instance.speed = speed
    effekseer.set_speed(instance.handle, instance.playid, speed)
end

function iplay.set_time_callback(callback)
    time_callback = callback
end

local itimer = ecs.import.interface "ant.timer|itimer"

local function main_camera_ref()
    for v in world.w:select "main_queue camera_ref:in" do
        return v.camera_ref
    end
end

function effekseer_sys:camera_usage()
    local icamera = ecs.import.interface "ant.camera|camera"
    local c = icamera.find_camera(main_camera_ref())
    if c then
        effekseer.update_view_proj(math3d.value_ptr(c.viewmat), math3d.value_ptr(c.projmat))
    end
end

local iom = ecs.import.interface "ant.objcontroller|obj_motion"
local event_entity_register = world:sub{"entity_register"}
local event_play_effect = world:sub{"play_effect"}
local event_do_play = world:sub{"do_play"}
function effekseer_sys:render_submit()
    for tm_q in w:select "tonemapping_queue render_target:in" do
        --local tm_q = assert(w:singleton("tonemapping_queue", "render_target:in"))
        local effect_view = viewidmgr.get "effect_view"
        local tm_rt = tm_q.render_target
        fbmgr.bind(effect_view, tm_rt.fb_idx)
        local vr = tm_rt.view_rect
        bgfx.set_view_rect(effect_view, vr.x, vr.y, vr.w, vr.h)
        local dt = time_callback and time_callback() or itimer.delta() * 0.001
        effekseer.update(dt)
    end
end

function effekseer_sys:follow_transform_updated()
    for _, eid in event_entity_register:unpack() do
        for e in w:select "effekseer:in effect_instance:in" do
            if e.effect_instance then
                if e.effect_instance.auto_play then
                    world:pub {"play_effect", e.effect_instance}
                end
            end
        end
    end

    for _, inst, lp in event_do_play:unpack() do
        inst.playid = effekseer.play(inst.handle, inst.playid)
        effekseer.set_speed(inst.handle, inst.playid, inst.speed)
    end

    for _, inst, lp in event_play_effect:unpack() do
        world:pub {"do_play", inst, lp}
    end

    for v in w:select "effect_instance:in scene:in" do
        v.effect_instance.worldmat = v.scene._worldmat
        effekseer.update_transform(v.effect_instance.handle, v.effect_instance.playid, v.scene._worldmat)
    end
end

function effekseer_sys:entity_remove()
    for e in w:select "REMOVED effekseer:in effect_instance:in" do
        effekseer.stop(e.effect_instance.handle, e.effect_instance.playid)
    end
end

function effekseer_sys:exit()
    effekseer.shutdown()
end