local ecs   = ...
local world = ecs.world
local w     = world.w

local math3d    = require "math3d"
local assetmgr  = import_package "ant.asset"
local imaterial = ecs.require "ant.asset|material"

local rm  = ecs.system "rotator_system"

local TICK_CYCLE     = 300
local ROTATOR_CYCLES = 2 * math.pi
local DELTA_RAD      = ROTATOR_CYCLES / TICK_CYCLE
local CUR_RAD        = 0.0

function rm:data_changed()
    CUR_RAD = CUR_RAD + DELTA_RAD

    if CUR_RAD >= ROTATOR_CYCLES then
        CUR_RAD = 0
    end

    for e in w:select "material:in" do
        local r = assetmgr.resource(e.material)
        if r.properties["u_rotator_rate"] then
            imaterial.set_property(e, "u_rotator_rate", math3d.vector{CUR_RAD, 0, 0, 0})
        end
    end
end