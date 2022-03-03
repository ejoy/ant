local ecs   = ...
local world = ecs.world
local w     = world.w

local cs2cm_sys = ecs.system "cs2cm_system"

local renderpkg = import_package "ant.render"
local viewidmgr = renderpkg.viewidmgr
local fbmgr     = renderpkg.fbmgr
local sampler   = renderpkg.sampler

local imaterial = ecs.import.interface "ant.asset|imaterial"
local icompute  = ecs.import.interface "ant.render|icompute"

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

local cubemap_flags<const> = sampler.sampler_flag {
    MIN="LINEAR",
    MAG="LINEAR",
    MIP="LINEAR",
    U="CLAMP",
    V="CLAMP",
    W="CLAMP",
    RT="RT_ON",
}

local build_ibl_viewid = viewidmgr.get "build_ibl"

function cs2cm_sys:convert_sky()
    w:clear "filter_ibl"
    for e in w:select "sky_changed skybox:in render_object:in filter_ibl?out" do
        local tex = imaterial.get_property(e).value.texture
        --TODO: if we changed skybox texture, we should remove cubemap render texture
        local ti = tex.info
        if ti.depth == 1 and ti.width == ti.height*2 then
            local facesize = ti.height // 2
            local cm_rbidx = fbmgr.create_rb{format="RGBA32F", size=facesize, layers=1, mipmap=true, flags=cubemap_flags, cubemap=true}
            local ro = e.render_object

            local properties = ro.properties

            imaterial.set_property_directly(properties, "s_source", {stage=0, texture=tex})
            local p = icompute.create_image_property(fbmgr.get_rb(cm_rbidx).handle, 1, 0, "w")
            imaterial.set_property_directly(properties, "s_cubemap_source", p)

            local dis = e.dispatch
            dis[1], dis[2], dis[3] = facesize // thread_group_size, facesize // thread_group_size, 6
            icompute.dispatch(build_ibl_viewid, dis)

            fbmgr.create{
                rbidx = cm_rbidx,
                
            }
        end



        e.filter_ibl = true
    end
end

function cs2cm_sys:filter_ibl()
    for e in w:select "filter_ibl render_object:in" do

    end
end

