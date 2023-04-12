local ecs       = ...
local world     = ecs.world
local w         = world.w

local math3d    = require "math3d"

local imaterial = ecs.import.interface "ant.asset|imaterial"
local timer 	= ecs.import.interface "ant.timer|itimer"

local printer_sys = ecs.system 'printer_system'
local iprinter = ecs.interface "iprinter"






function printer_sys:data_changed()

    for e in w:select "printer:update eid:in" do
        local printer = e.printer
        printer.eid = e.eid
        iprinter.update_printer_percent(printer.eid, printer.percent) 
    end    
end


--[[ function printer_sys:follow_transform_updated()
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

end ]]



function iprinter.update_printer_percent(eid, percent)
    for e in w:select "printer:update bounding?in" do
        local printer = e.printer
        if printer.eid == eid then
            assert(percent <= 1.0 and percent >= 0.0)
            local aabb = e.bounding.scene_aabb
            local topy = math3d.index(math3d.array_index(aabb, 2), 2)
            local boty = math3d.index(math3d.array_index(aabb, 1), 2)
            local cury = percent * (topy - boty) + boty
            local offy
            if cury - 0.1 * (topy - boty) >= boty then
                offy = 0.1 * (topy - boty)
            else
                offy = cury-boty
            end
            if topy - cury <= 0.1 * (topy - boty) then
                offy = 0
            end
            local factor = math3d.vector(offy, cury, 0, 0)
            imaterial.set_property(e, "u_printer_factor", factor)
            printer.percent = percent  
        end
    end    
end