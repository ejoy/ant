local ecs       = ...
local world     = ecs.world
local w         = world.w

local math3d    = require "math3d"

local imaterial = ecs.import.interface "ant.asset|imaterial"
local timer 	= ecs.import.interface "ant.timer|itimer"

local printer_sys = ecs.system 'printer_system'
function printer_sys:init()

end


function printer_sys:follow_transform_updated()
    for e in w:select "printer:in bounding?in" do
        local current = e.printer.previous + timer.delta() / 1000
        if current > e.printer.duration then
            e.printer = nil
        else
            e.printer.previous = current
            local aabb = e.bounding.scene_aabb
            local factor = math3d.lerp(math3d.array_index(aabb, 1), math3d.array_index(aabb, 2), current / e.printer.duration)
            imaterial.set_property(e, "u_printer_factor", factor)
        end
    end

end
