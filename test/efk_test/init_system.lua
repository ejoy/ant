local ecs   = ...
local world = ecs.world
local w     = world.w

local renderpkg = import_package "ant.render"
local viewidmgr = renderpkg.viewidmgr
local declmgr   = renderpkg.declmgr
local fbmgr     = renderpkg.fbmgr
local samplerutil=renderpkg.sampler
local mathpkg   = import_package "ant.math"
local mc        = mathpkg.constant

local math3d    = require "math3d"

local iefk      = ecs.import.interface "ant.efk|iefk"
local iom       = ecs.import.interface "ant.objcontroller|iobj_motion"

local is = ecs.system "init_system"

function is:init()
    world:create_entity {
        policy = {
            "ant.general|name",
            "ant.scene|scene_object",
            "ant.efk|efk",
        },
        data = {
            scene   = {srt = {}},
            efk     = "/pkg/ant.efk/efkbgfx/examples/resources/Laser01.efk",
            name    = "test_efk",
            on_ready = function (e)
                w:sync("efk:in", e)
                e.efk.eff_handle = iefk.play(e)
            end
        },
    }
end

function is:init_world()
    local mq = w:singleton("main_queue", "camera_ref:in")
    local ce = world:entity(mq.camera_ref)
    iom.set_position(ce, math3d.vector(0.0, 0.0, 10.0))
    iom.set_direction(ce, math3d.vector(0.0, 0.0, -1.0))
end

function is:data_changed()

end