local ecs = ...
local world = ecs.world
local w     = world.w
local outline_system = ecs.system "outline_system"
local ioutline = ecs.interface "ioutline"
local math3d	= require "math3d"
local bgfx		= require "bgfx"
local imaterial = ecs.import.interface "ant.asset|imaterial"

local default_stencil = {
    TEST =  "ALWAYS",
    FUNC_REF =  1,
    FUNC_RMASK = 255,
    OP_FAIL_S = "REPLACE",
    OP_FAIL_Z = "REPLACE",
    OP_PASS_Z =  "REPLACE"
}

local scale_id_table = {}

--[[ local function is_gpu_skinning(declname)
    if string.find(declname, "w40") or string.find(declname, "i40") then
        return true
    else return 
    end
end ]]

function outline_system:data_changed()
    for e in w:select "outline:update filter_material:in scene:in mesh:in scene:in eid:in skinning?in" do
        if e.filter_material and e.outline.outline_mesh then
            local outline_eid = e.eid
            local render_layer = e.outline.render_layer
            local outline_color = e.outline.outline_color
            local outline_scale = e.outline.outline_scale
            local outline_mesh  = e.outline.outline_mesh
            local fm = e.filter_material
            local old_stencil = fm["main_queue"]:get_stencil()
            local new_stencil = bgfx.make_stencil(default_stencil)
            local outline_material
            if e.skinning then outline_material = "/pkg/ant.resources/materials/outline/scale_skinning.material"
            else outline_material = "/pkg/ant.resources/materials/outline/scale.material" end
            fm["main_queue"]:set_stencil(new_stencil)
            local scale_eid = ecs.create_entity{
                policy = {
                    "ant.scene|scene_object",
                    "ant.render|render"
                },
                data = {
                    scene = {
                        s = e.scene.s, r = e.scene.r, t = e.scene.t
                    },
                    mesh  = outline_mesh,
                    material    = outline_material,
                    skinning = e.skinning,
                    on_ready = function (ee)
                         if outline_scale then
                            imaterial.set_property(ee, "u_outlinescale", math3d.vector(outline_scale, 0, 0, 0)) 
                        end
                        if outline_color then
                            imaterial.set_property(ee, "u_outlinecolor", math3d.vector(outline_color)) 
                        end
                    end,
                    visible_state = "main_view",
                    render_layer = render_layer,
                    outline_info = {
                        old_stencil = old_stencil,
                    }
                },
                
            }
            scale_id_table[outline_eid] = scale_eid
            e.outline = {}
        end
    end
end

function ioutline.remove_outline(outline_eid)
    if scale_id_table[outline_eid] then
        w:remove(scale_id_table[outline_eid]) 
    end
end