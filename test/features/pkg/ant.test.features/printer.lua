local ecs = ...
local world = ecs.world
local w = world.w
local math3d = require "math3d"
local imaterial = ecs.import.interface "ant.asset|imaterial"
local printer_sys = ecs.system 'printer_system'
local irender   = ecs.import.interface "ant.render|irender"
local timer 		= ecs.import.interface "ant.timer|itimer"
local iterrain  = ecs.import.interface "ant.terrain|iterrain"
local material_cache = {__mode="k"}
local printer_material

function printer_sys:init()
     printer_material = imaterial.load_res "/pkg/ant.resources/materials/printer.material"
     ecs.create_entity {
        policy = {
            "ant.render|render",
            "ant.general|name",
        },
        data = {
            primitive_filter = {
                filter_type = "postprocess_obj",
                "opacity",
                "translucent",
            },
            name        = "printer_test",
            scene  = {s = 0.2, t = {5, 0, 5}},
            material    = "/pkg/ant.resources/materials/printer.material",
            visible_state = "postprocess_obj",
            mesh        = "/pkg/ant.test.features/assets/glb/electric-pole-1.glb|meshes/Cylinder.006_P1.meshbin",
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

local function which_material(skinning)
	return skinning or printer_material
end


function printer_sys:update_filter()
  	for e in w:select "filter_result postprocess_obj_queue_visible render_layer:in render_object:update filter_material:in skinning?in" do
        if e.render_layer == "opacity" then
            local m = which_material(e.skinning)
            local mo = m.object
            local ro = e.render_object
            local fm = e.filter_material
            local newstate = irender.check_set_state(mo, fm.main_queue)
            local new_matobj = irender.create_material_from_template(mo, newstate, material_cache)
            local mi = new_matobj:instance()
            local h = mi:ptr()
            fm["postprocess_obj_queue"] = mi
            ro.mat_ppoq = h
        end
	end  
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

function printer_sys:render_submit()

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
            local center, extent = math3d.aabb_center_extents(e.bounding.scene_aabb)
            local minY, maxY = math3d.index(center, 2) - math3d.index(extent, 2), math3d.index(center, 2) + math3d.index(extent, 2)
            local y = math3d.index(math3d.lerp(math3d.vector(minY, 0, 0), math3d.vector(maxY, 0, 0), current / e.printer.duration), 1)
            imaterial.set_property(e, "u_printer_factor", math3d.vector(y, 0.0, 0.0, 0.0), "postprocess_obj_queue")
        end
    end

end
