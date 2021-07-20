local ecs = ...
local world = ecs.world
local assetmgr      = import_package "ant.asset"
local math3d        = require "math3d"
local effekseer     = require "effekseer"

local renderpkg     = import_package "ant.render"
local declmgr       = renderpkg.declmgr
local viewidmgr     = renderpkg.viewidmgr

local math3d_adapter = require "math3d.adapter"
effekseer.update_transform = math3d_adapter.matrix(effekseer.update_transform, 2, 1)

local effekseer_sys = ecs.system "effekseer_system"
local time_callback
-- local m = ecs.component "effekseer"

-- function m:init()
-- 	effekseer.set_loop(self.handle, self.loop)
--     effekseer.set_speed(self.handle, self.speed)
--     if e.auto_play then
--         effekseer.play(self.handle)
--     end
-- end

local ie_t = ecs.transform "instance_effect"

function ie_t.process_entity(e)
    e.effect_instance = {
        handle 		= effekseer.create(e.effekseer.rawdata, e.effekseer.filedir),
        speed 		= e.speed,
        auto_play 	= e.auto_play,
        loop 		= e.loop
    }
end

local shader_type = {
    "unlit","lit","distortion","ad_unlit","ad_lit","ad_distortion","mtl"
}

function effekseer_sys:init()
    local path = "/pkg/ant.resources/shaders/effekseer/"
    local sprite_shader_defines = {}
    local model_shader_defines = {}
    for _, type in ipairs(shader_type) do
        sprite_shader_defines[type] = {
            -- fs = path .. "fs_model_" .. type .. ".sc",
            -- vs = path .. "vs_sprite_" .. type .. ".sc",
            fs = path .. "fs_model_unlit.sc",
            vs = path .. "vs_sprite_unlit.sc",
            setting = {}
        }
    end
    for _, type in ipairs(shader_type) do
        model_shader_defines[type] = {
            -- fs = path .. "fs_model_" .. type .. ".sc",
            -- vs = path .. "vs_model_" .. type .. ".sc",
            fs = path .. "fs_model_unlit.sc",
            vs = path .. "vs_model_unlit.sc",
            setting = {}
        }
    end

    local function create_shaders(def)
        local programs = {}
        for k, v in pairs(def) do
            programs[#programs + 1] = assetmgr.load_fx(v)
        end
        return programs
    end

    effekseer.init {
        viewid = viewidmgr.get "main_view",
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
    filemgr.add("/pkg/ant.resources.binary/effekseer/Base")
end

local imgr = ecs.interface "filename_mgr"

function imgr.add_path(path)
    local filemgr = require "filemanager"
    filemgr.add(path)
end

local iplay = ecs.interface "effekseer_playback"

function iplay.play(eid, loop)
    local eh = world[eid].effect_instance.handle
    if effekseer.is_playing(eh) then return end
    --effekseer.set_speed(eh, speed or 1.0)
    local lp = loop or false
    -- world[eid].loop = lp
    effekseer.set_loop(eh, lp)
    effekseer.play(eh)
end

function iplay.is_playing(eid)
    local eh = world[eid].effect_instance.handle
    return effekseer.is_playing(eh)
end

function iplay.pause(eid, b)
    local eh = world[eid].effect_instance.handle
    effekseer.pause(eh, b)
end

function iplay.set_time(eid, second)
    local eh = world[eid].effect_instance.handle
    local frame = math.floor(second * 60)
    effekseer.set_time(eh, frame)
end

function iplay.set_speed(eid, speed)
    local eh = world[eid].effect_instance.handle
    world[eid].speed = speed
    effekseer.set_speed(eh, speed)
end

function iplay.set_time_callback(callback)
    time_callback = callback
end

local itimer = world:interface "ant.timer|itimer"

function effekseer_sys:camera_usage()
    local mq = world:singleton_entity "main_queue"
    local icamera = world:interface "ant.camera|camera"
    local rc = world[mq.camera_eid]._rendercache
    effekseer.update_view_proj(math3d.value_ptr(rc.viewmat), math3d.value_ptr(rc.projmat))
end


local iom = world:interface "ant.objcontroller|obj_motion"
local event_entity_register = world:sub{"entity_register"}
function effekseer_sys:ui_update()
    -- for _, eid in event_entity_register:unpack() do
    --     if world[eid] and world[eid].effect_instance then
    --         local eh = world[eid].effect_instance.handle
    --         effekseer.set_loop(eh, world[eid].loop)
    --         effekseer.set_speed(eh, world[eid].speed)
    --         if world[eid].auto_play then
    --             effekseer.play(eh)
    --         end
    --     end
    -- end
    for _, eid in world:each "removed" do
        local e = world[eid]
        if e.effect_instance then
            effekseer.destroy(e.effect_instance.handle)
        end
    end
    for _, eid in world:each "effekseer" do
		local e = world[eid]
		effekseer.update_transform(e.effect_instance.handle, iom.worldmat(eid))
    end
    local dt = time_callback and time_callback() or itimer.delta() * 0.001
    effekseer.update(dt)
end

function effekseer_sys:follow_transform_updated()

end

function effekseer_sys:exit()
    effekseer.shutdown()
end