local ecs   = ...
local world = ecs.world
local w     = world.w

local cs2cm_sys = ecs.system "cs2cm_system"

local renderpkg = import_package "ant.render"
local viewidmgr = renderpkg.viewidmgr
local fbmgr     = renderpkg.fbmgr
local sampler   = renderpkg.sampler

local assetmgr  = import_package "ant.asset"

local setting   = import_package "ant.settings".setting
local irradianceSH_bandnum<const> = setting:get "graphic/ibl/irradiance_bandnum"

local imaterial = ecs.import.interface "ant.asset|imaterial"
local icompute  = ecs.import.interface "ant.render|icompute"
local iibl      = ecs.import.interface "ant.render|iibl"
local icubemap_mipmap = ecs.import.interface "ant.sky|icubemap_mipmap"
local rhwi      = import_package "ant.hwi"
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
            material    = "/pkg/ant.sky/assets/panorama2cubemap.material",
            dispatch    ={
                size    = {
                    0, 0, 0
                },
            },
            compute     = true,
        }
    }
end

local p2c_viewid = viewidmgr.get "panorama2cubmap"
local cm_flags = sampler{
    MIN="LINEAR",
    MAG="LINEAR",
    MIP="LINEAR",
    U="CLAMP",
    V="CLAMP",
    W="CLAMP",
    RT="RT_ON",
    BLIT="BLIT_COMPUTEWRITE",
}

local function res_tex(e)
    return imaterial.resource(e).properties.s_skybox.texture
end

local function load_res_tex(e)
    return assetmgr.resource(res_tex(e))
end


function cs2cm_sys:entity_ready()
    for e in w:select "skybox_changed:update render_object filter_material:in skybox:in filter_ibl?out" do
        local tex = load_res_tex(e)
        if not assetmgr.invalid_texture(tex.id) then
            e.skybox_changed = false
            local ti = tex.texinfo
            if panorama_util.is_panorama_tex(ti) then
                if e.skybox.facesize == nil then
                    e.skybox.facesize = ti.height // 2
                else
                    e.skybox.facesize = math.min(ti.width, ti.height // 2)
                end
                local facesize = e.skybox.facesize
                local cm_rbidx = panorama_util.check_create_cubemap_tex(facesize, e.skybox.cm_rbidx, cm_flags)
                e.skybox.cm_rbidx = cm_rbidx
    
                local dispatcher <close> = w:entity(cs2cm_convertor_eid, "dispatch:in")
                local dis = dispatcher.dispatch
                local material = dis.material
    
                local cm_rbhandle = fbmgr.get_rb(cm_rbidx).handle
                material.s_source = tex.id
                material.s_cubemap_source = icompute.create_image_property(cm_rbhandle, 1, 0, "w")
    
                local s = dis.size
                s[1], s[2], s[3] = facesize // thread_group_size, facesize // thread_group_size, 6
                icompute.dispatch(p2c_viewid, dis)
                icubemap_mipmap.gen_cubemap_mipmap(facesize, cm_rbhandle)
                imaterial.set_property(e, "s_skybox", cm_rbhandle)
            end
            e.filter_ibl = true
        end
    end
end

function cs2cm_sys:filter_ibl()
    for e in w:select "filter_ibl:update render_object ibl:in skybox:in" do
        local se_ibl = e.ibl
        local sb = e.skybox
        local cm_rbhandle
        if sb.cm_rbidx then
            cm_rbhandle = fbmgr.get_rb(sb.cm_rbidx).handle
        else
            local texid = load_res_tex(e).id
            if not assetmgr.invalid_texture(texid) then
                cm_rbhandle = texid
            end
        end
        
        if cm_rbhandle then
            iibl.filter_all{
                source 		= {value=cm_rbhandle, facesize=sb.facesize, res_tex = res_tex(e)},
                irradiance 	= se_ibl.irradiance,
                irradianceSH= se_ibl.irradianceSH,
                prefilter 	= se_ibl.prefilter,
                LUT			= se_ibl.LUT,
                intensity	= se_ibl.intensity,
            }
            world:pub{"ibl_updated", e}

            e.filter_ibl = false
        end
    end
end

