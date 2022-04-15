local ecs   = ...
local world = ecs.world
local w     = world.w

local bgfx      = require "bgfx"

local cs2cm_sys = ecs.system "cs2cm_system"

local renderpkg = import_package "ant.render"
local viewidmgr = renderpkg.viewidmgr
local fbmgr     = renderpkg.fbmgr
local sampler   = renderpkg.sampler

local imaterial = ecs.import.interface "ant.asset|imaterial"
local icompute  = ecs.import.interface "ant.render|icompute"
local iibl      = ecs.import.interface "ant.render|iibl"

local panorama_util=require "panorama.util"

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

local build_ibl_viewid = viewidmgr.get "build_ibl"
local cm_flags = sampler.sampler_flag{
    MIN="LINEAR",
    MAG="LINEAR",
    MIP="LINEAR",
    U="CLAMP",
    V="CLAMP",
    W="CLAMP",
    RT="RT_ON",
    BLIT="BLIT_COMPUTEWRITE",
}

function cs2cm_sys:entity_ready()
    for e in w:select "skybox_changed skybox:in render_object:in filter_ibl?out" do
        local tex = imaterial.get_property(e, "s_skybox").value.texture

        local ti = tex.texinfo
        if panorama_util.is_panorama_tex(ti) then
            if e.skybox.facesize == nil then
                e.skybox.facesize = ti.height // 2
            end
            local facesize = e.skybox.facesize
            local cm_rbidx = panorama_util.check_create_cubemap_tex(facesize, e.skybox.cubeme_rbidx, cm_flags)
            e.skybox.cubeme_rbidx = cm_rbidx

            local dispatcher = world:entity(cs2cm_convertor_eid)
            local dis = dispatcher.dispatch
            local properties = dis.properties

            local cm_rbhandle = fbmgr.get_rb(cm_rbidx).handle
            imaterial.set_property_directly(properties, "s_source", {stage=0, texture=tex})
            properties.s_cubemap_source = icompute.create_image_property(cm_rbhandle, 1, 0, "w")

            local s = dis.size
            s[1], s[2], s[3] = facesize // thread_group_size, facesize // thread_group_size, 6
            icompute.dispatch(build_ibl_viewid, dis)

            --just generate mipmaps for cm_rbidx
            local fbidx = fbmgr.create{
                rbidx = cm_rbidx,
                resolve = "g",
                layer = 0,
                mip = 0,
                numlayer = 1,
            }
            bgfx.set_view_frame_buffer(build_ibl_viewid, fbmgr.get(fbidx).handle)
            bgfx.touch(build_ibl_viewid)

            fbmgr.destroy(fbidx, true)

            imaterial.set_property(e, "s_skybox", {stage=0, texture={handle=cm_rbhandle}})
        end
        e.filter_ibl = true
    end
end

function cs2cm_sys:filter_ibl()
    for e in w:select "filter_ibl ibl:in skybox:in render_object:in" do
        local se_ibl = e.ibl
        local tex = imaterial.get_property(e, "s_skybox").value.texture
        iibl.filter_all{
			source 		= {handle = tex.handle, cubemap=true, facesize = e.skybox.facesize},
			irradiance 	= se_ibl.irradiance,
			prefilter 	= se_ibl.prefilter,
			LUT			= se_ibl.LUT,
			intensity	= se_ibl.intensity,
		}
		world:pub{"ibl_updated", e}
    end
    w:clear "filter_ibl"
end

