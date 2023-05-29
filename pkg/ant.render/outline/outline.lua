local ecs = ...
local world = ecs.world
local w     = world.w
local outline_system = ecs.system "outline_system"
--local ioutline = ecs.interface "ioutline"
local math3d	= require "math3d"
local bgfx		= require "bgfx"
local imaterial = ecs.import.interface "ant.asset|imaterial"

local DEFAULT_STENCIL<const> = bgfx.make_stencil{
    TEST =  "ALWAYS",
    FUNC_REF =  1,
    FUNC_RMASK = 255,
    OP_FAIL_S = "REPLACE",
    OP_FAIL_Z = "REPLACE",
    OP_PASS_Z =  "REPLACE"
}


function outline_system:data_changed()
    for e in w:select "outline_pre:update filter_material:update" do
        local fm = e.filter_material
        fm["main_queue"]:set_stencil(DEFAULT_STENCIL)
        e.outline_pre = nil
    end

    for e in w:select "outline_info:update" do
        if e.outline_info.outline_color then
            local outline_scale, outline_color = e.outline_info.outline_scale, e.outline_info.outline_color
            imaterial.set_property(e, "u_outlinescale", math3d.vector(outline_scale, 0, 0, 0))
            imaterial.set_property(e, "u_outlinecolor", math3d.vector(outline_color))
            e.outline_info = {} 
        end
    end  
--[[     for e in w:select "outline:update outline_create:update filter_material:in eid:in skinning?in scene?in mesh?in" do
        if e.filter_material then
            local render_layer = e.outline_create.render_layer
            local outline_color = e.outline_create.outline_color
            local outline_scale = e.outline_create.outline_scale
            local fm = e.filter_material
            local outline_material
            local scene = {}
            if e.scene then
                scene.s, scene.r, scene.t = e.scene.s, e.scene.r, e.scene.t
            end
            if e.skinning then outline_material = "/pkg/ant.resources/materials/outline/scale_skinning.material"
            else outline_material = "/pkg/ant.resources/materials/outline/scale.material" end
            fm["main_queue"]:set_stencil(DEFAULT_STENCIL)
            local outline_eid = ecs.create_entity{
                policy = {
                    "ant.scene|scene_object",
                    "ant.render|render"
                },
                data = {
                    scene = scene,
                    mesh  = tostring(e.mesh),
                    material    = outline_material,
                    skinning = e.skinning,
                    visible_state = "main_view",
                    render_layer = render_layer,
                    on_ready = function (ee)
                        if outline_scale then
                           imaterial.set_property(ee, "u_outlinescale", math3d.vector(outline_scale, 0, 0, 0)) 
                       end
                       if outline_color then
                           imaterial.set_property(ee, "u_outlinecolor", math3d.vector(outline_color)) 
                       end
                   end,
                },
                
            }
            outline_eid_table[e.eid] = outline_eid
            e.outline_create = {}
            e.outline = nil
        end
    end

    for e in w:select "outline_remove:update eid:in" do
        w:remove(outline_eid_table[e.eid])
        e.outline_remove = nil
    end ]]
end
