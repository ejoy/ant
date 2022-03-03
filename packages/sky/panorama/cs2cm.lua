local ecs   = ...
local world = ecs.world
local w     = world.w

local cs2cm_sys = ecs.system "cs2cm_system"

local renderpkg = import_package "ant.render"
local viewidmgr = renderpkg.viewidmgr
local fbmgr     = renderpkg.fbmgr

local imaterial = ecs.import.interface "ant.asset|imaterial"

local thread_group_size<const> = 32

local cs2cm_convertor_eid
function cs2cm_sys:init()
    cs2cm_convertor_eid = ecs.create_entity {
        policy = {
            "ant.render|compute_policy",
            "ant.general|name",
        },
        data = {
            name        = "cs2cm_convertor",
            material    = "/pkg/ant.resources/materials/panorama2cubemap.material",
            dispatch    ={
                size    = {
                    0, 0, 0
                },
            },
            compute     = true,
        }
    }
end

function cs2cm_sys:convert_sky()
    w:clear "filter_ibl"
    for e in w:select "sky_changed skybox:in render_object:in filter_ibl?out" do
        local tex = imaterial.get_property(e).value.texture
        local ti = tex.info
        if ti.depth == 1 and ti.width == ti.height*2 then
            local facesize = ti.height // 2

        end

        e.filter_ibl = true
    end
end

function cs2cm_sys:filter_ibl()
    for e in w:select "filter_ibl render_object:in" do
        
    end
end

