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

-- local m = ecs.component "effekseer"

-- function m:init()
-- 	effekseer.set_loop(self.handle, self.loop)
--     effekseer.set_speed(self.handle, self.speed)
--     if e.auto_play then
--         effekseer.play(self.handle)
--     end
-- end

function effekseer_sys:init()
    local shader_defines = {
        unlit = {
            fs = "/pkg/ant.resources/shaders/effekseer/fs_model_unlit.sc",
            vs = "/pkg/ant.resources/shaders/effekseer/vs_sprite_unlit.sc",
            setting = {}
        },
        lit = {
            fs = "/pkg/ant.resources/shaders/effekseer/fs_model_unlit.sc",
            vs = "/pkg/ant.resources/shaders/effekseer/vs_sprite_unlit.sc",
            setting = {}
        },
        distortion = {
            fs = "/pkg/ant.resources/shaders/effekseer/fs_model_unlit.sc",
            vs = "/pkg/ant.resources/shaders/effekseer/vs_sprite_unlit.sc",
            setting = {}
        },
        ad_unlit = {
            fs = "/pkg/ant.resources/shaders/effekseer/fs_model_unlit.sc",
            vs = "/pkg/ant.resources/shaders/effekseer/vs_sprite_unlit.sc",
            setting = {}
        },
        ad_lit = {
            fs = "/pkg/ant.resources/shaders/effekseer/fs_model_unlit.sc",
            vs = "/pkg/ant.resources/shaders/effekseer/vs_sprite_unlit.sc",
            setting = {}
        },
        ad_distortion = {
            fs = "/pkg/ant.resources/shaders/effekseer/fs_model_unlit.sc",
            vs = "/pkg/ant.resources/shaders/effekseer/vs_sprite_unlit.sc",
            setting = {}
        },
        mtl = {
            fs = "/pkg/ant.resources/shaders/effekseer/fs_model_unlit.sc",
            vs = "/pkg/ant.resources/shaders/effekseer/vs_sprite_unlit.sc",
            setting = {}
        }
    }
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
        programs = create_shaders(shader_defines),
        unlit_layout = declmgr.get "p3|c40niu|t20".handle,
        lit_layout = declmgr.get "p3|c40niu|n40niu|T40niu|t20|t21".handle,
        distortion_layout = declmgr.get "p3|c40niu|n40niu|T40niu|t20|t21".handle,
        ad_unlit_layout = declmgr.get "p3|c40niu|t20|t41|t42|t43".handle,
        ad_lit_layout = declmgr.get "p3|c40niu|n40niu|T40niu|t20|t21|t42|t43|t44".handle,
        ad_distortion_layout = declmgr.get "p3|c40niu|n40niu|T40niu|t20|t21|t42|t43|t44".handle,
        mtl_layout = declmgr.get "p3|c40niu|n40niu|T40niu|t20|t21|t42|t43".handle
    }

    local filemgr = require "filemanager"
    effekseer.set_filename_callback(filemgr.realpath)
    filemgr.add("/pkg/ant.resources.binary/effekseer/Base")
end

local iplay = ecs.interface "effekseer_playback"

function iplay.play(eid, loop, speed)
    local eh = world[eid].effekseer.handle
    effekseer.set_speed(eh, speed or 1.0)
    effekseer.set_loop(eh, loop or false)
    effekseer.play(eh)
end

local itimer = world:interface "ant.timer|timer"

function effekseer_sys:camera_usage()
    local mq = world:singleton_entity "main_queue"
    local icamera = world:interface "ant.camera|camera"
    local rc = world[mq.camera_eid]._rendercache
    effekseer.update_view_proj(math3d.value_ptr(rc.viewmat), math3d.value_ptr(rc.projmat))
end


local iom = world:interface "ant.objcontroller|obj_motion"
local event_entity_register = world:sub{"entity_register"}
function effekseer_sys:ui_update()
    for _, eid in event_entity_register:unpack() do
        if world[eid] and world[eid].effekseer then
            local eh = world[eid].effekseer.handle
            effekseer.set_loop(eh, world[eid].loop)
            effekseer.set_speed(eh, world[eid].speed)
            if world[eid].auto_play then
                effekseer.play(eh)
            end
        end
    end
    
    for _, eid in world:each "effekseer" do
		local e = world[eid]
		effekseer.update_transform(e.effekseer.handle, iom.worldmat(eid))
    end
    local dt = itimer.delta() * 0.001
    effekseer.update(dt)
end

function effekseer_sys:follow_transform_updated()

end

function effekseer_sys:exit()
    effekseer.shutdown()
end