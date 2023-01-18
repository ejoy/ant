local ecs       = ...
local world     = ecs.world
local w         = world.w

local math3d    = require "math3d"

local imaterial = ecs.import.interface "ant.asset|imaterial"
local timer 	= ecs.import.interface "ant.timer|itimer"
local iterrain  = ecs.import.interface "ant.terrain|iterrain"

local printer_sys = ecs.system 'printer_system'
function printer_sys:init()
     ecs.create_entity {
        policy = {
            "ant.render|render",
            "ant.general|name",
        },
        data = {
            primitive_filter = {
                filter_type = "main_view",
            },
            name        = "printer_test",
            scene  = {s = 0.2, t = {5, 0, 5}},
            material    = "/pkg/mod.printer/assets/printer.material",
            visible_state = "main_view",
            mesh        = "/pkg/mod.printer/assets/electric-pole-1.glb|meshes/Cylinder.006_P1.meshbin",
            render_layer= "postprocess_obj",
            -- add printer tag
            -- previous still be zero
            -- duration means generation duration time
            printer = {
                previous = 0,
                duration = 5
            }
        },
    }

end

local mark = false
-- x y
local delete_list = {
    {1, 1},
    {2, 1},
    {3, 1},
    {1, 2},
    {3, 2},
    {1, 3},
    {2, 3},
    {3, 3},
}

local update_list = {
    {7, 1, "White", "I", "E"},
    {8, 1, "Red",   "I", "E"},
    {9, 1, "Red",   "I", "E"},
}

function printer_sys:follow_transform_updated()
    for e in w:select "printer:in bounding?in" do
        local current = e.printer.previous + timer.delta() / 1000
        if current > e.printer.duration then
            e.printer = nil
            if mark == false then
                iterrain.delete_roadnet_entity(delete_list)
                iterrain.update_roadnet_entity(update_list)
                mark = true
            end
        else
            e.printer.previous = current
            local aabb = e.bounding.scene_aabb
            local factor = math3d.lerp(math3d.array_index(aabb, 1), math3d.array_index(aabb, 2), current / e.printer.duration)
            imaterial.set_property(e, "u_printer_factor", factor)
        end
    end

end
