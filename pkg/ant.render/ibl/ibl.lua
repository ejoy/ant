local ecs       = ...
local world     = ecs.world
local w         = world.w

local bgfx      = require "bgfx"
local math3d    = require "math3d"

local assetmgr  = import_package "ant.asset"
local renderpkg = import_package "ant.render"
local sampler   = renderpkg.sampler

local hwi       = import_package "ant.hwi"
local serialize = import_package "ant.serialize"

local icompute  = ecs.require "ant.render|compute.compute"
local iexposure = ecs.require "ant.camera|exposure"
local imaterial = ecs.require "ant.render|material"

local setting   = import_package "ant.settings"
local irradianceSH_bandnum<const> = setting:get "graphic/ibl/irradiance_bandnum"
local ENABLE_IBL_LUT<const>       = setting:get "graphic/ibl/enable_lut"
local USE_RGB10A2<const>          = setting:get "graphic/ibl/use_rgb10a2"
local ibl_viewid<const> = hwi.viewid_get "ibl"

local thread_group_size<const> = 8

local ibl_sys = ecs.system "ibl_system"

local flags<const> = sampler {
    MIN="LINEAR",
    MAG="LINEAR",
    U="CLAMP",
    V="CLAMP",
    BLIT="BLIT_COMPUTEWRITE",
}

local cubemap_flags<const> = sampler {
    MIN="LINEAR",
    MAG="LINEAR",
    MIP="LINEAR",
    U="CLAMP",
    V="CLAMP",
    W="CLAMP",
    BLIT="BLIT_COMPUTEWRITE",
}

local IBL_INFO = {
    source = {facesize = 0, stage=0, value=nil, type="t"},
    prefilter    = {
        value = nil,
        size = 0,
        mipmap_count = 0,
        type="t",
    },
}

if irradianceSH_bandnum then
    IBL_INFO.irradiance = {
        value = nil,
        size = 0,
    }
else
    IBL_INFO.irradianceSH = {}
end

if ENABLE_IBL_LUT then
    IBL_INFO.LUT = {
        value = nil,
        size = 0,
    }
end

local function create_irradiance_entity()
    local size = IBL_INFO.irradiance.size
    local dispatchsize = {
        size / thread_group_size, size / thread_group_size, 6
    }
    icompute.create_compute_entity(
        "irradiance_builder", "/pkg/ant.resources/materials/ibl/build_irradiance.material", dispatchsize, function (e)
            w:extend(e, "dispatch:in")
            assetmgr.material_mark(e.dispatch.fx.prog)
        end)
end

local function create_irradianceSH_entity()
    world:create_entity {
        policy = {
            "ant.render|irradianceSH_builder",
        },
        data = {
            irradianceSH_builder = {},
        }
    }
end


local function create_prefilter_entities()
    local size = IBL_INFO.prefilter.size

    local mipmap_count = IBL_INFO.prefilter.mipmap_count
    local dr = 1 / (mipmap_count-1)
    local r = 0

    local function create_prefilter_compute_entity(dispatchsize, prefilter)
        world:create_entity {
            policy = {
                "ant.render|compute",
                "ant.render|prefilter",
            },
            data = {
                material    = "/pkg/ant.resources/materials/ibl/build_prefilter.material",
                dispatch    ={
                    size    = dispatchsize,
                },
                prefilter = prefilter,
                on_ready    = function (e)
                    w:extend(e, "dispatch:in")
                    assetmgr.material_mark(e.dispatch.fx.prog)
                end,
                prefilter_builder      = true,
            }
        }
    end


    for i=1, mipmap_count do
        local s = size >> (i-1)
        local dispatchsize = {
            math.floor(s / thread_group_size), math.floor(s / thread_group_size), 6
        }

        local prefilter = {
            roughness = r,
            sample_count = s,
            mipidx = i-1,
        }
        create_prefilter_compute_entity(dispatchsize, prefilter)

        r = r + dr
    end
end

local function create_LUT_entity()
    local size = IBL_INFO.LUT.size
    local dispatchsize = {
        size / thread_group_size, size / thread_group_size, 1
    }
    local function mark_prog(e)
        w:extend(e, "dispatch:in")
        assetmgr.material_mark(e.dispatch.fx.prog)
    end
   icompute.create_compute_entity(
        "LUT_builder", "/pkg/ant.resources/materials/ibl/build_LUT.material", dispatchsize, mark_prog)
end

local ibl_mb = world:sub{"ibl_changed"}
local exp_mb = world:sub{"exposure_changed"}

local function update_ibl_param(intensity)
    local mq = w:first("main_queue camera_ref:in")
    local camera <close> = world:entity(mq.camera_ref)
    local ev = iexposure.exposure(camera)

    intensity = intensity or 1
    intensity = intensity * IBL_INFO.intensity * ev
    imaterial.system_attrib_update("u_ibl_param", math3d.vector(IBL_INFO.prefilter.mipmap_count, intensity, 0.0 ,0.0))
end

local sample_count<const> = 512

function ibl_sys:render_preprocess()
    local source_tex = IBL_INFO.source

    for e in w:select "irradiance_builder dispatch:in" do
        local dis = e.dispatch
        local mi = dis.material

        mi.s_source             = source_tex
        mi.s_irradiance_write   = icompute.create_image_property(IBL_INFO.irradiance.value, 1, 0, "w")
        mi.u_build_ibl_param    = math3d.vector(sample_count, 0, IBL_INFO.source.facesize, 0.0)

        assert(assetmgr.material_isvalid(dis.fx.prog))
        icompute.dispatch(ibl_viewid, dis)
        w:remove(e)
    end

    for e in w:select "irradianceSH_builder" do
        local function load_Eml()
            local c = serialize.load(source_tex.tex_name .. "/source.ant")

            if nil == c.irradiance_SH then
                error(("source texture:%s, did not build irradiance SH, 'build_irradiance_sh' should add to cubemap texture"):format(source_tex.tex_name))
            end

            assert((irradianceSH_bandnum == 2 and #c.irradiance_SH == 3) or (irradianceSH_bandnum == 3 and #c.irradiance_SH == 7), "Invalid Eml data")
            return math3d.array_vector(c.irradiance_SH)
        end

        imaterial.system_attrib_update("u_irradianceSH", load_Eml())
        w:remove(e)
    end

    for e in w:select "prefilter_builder material:in dispatch:in prefilter:in" do
        local prefilter = e.prefilter
        local dis = e.dispatch
        local prefilter_stage<const> = 1

        local mi = dis.material
        mi.s_source             = source_tex
        mi.s_prefilter_write    = icompute.create_image_property(IBL_INFO.prefilter.value, prefilter_stage, prefilter.mipidx, "w")
        mi.u_build_ibl_param    = math3d.vector(sample_count, 0, IBL_INFO.source.facesize, prefilter.roughness)

        assert(assetmgr.material_isvalid(dis.fx.prog))
        icompute.dispatch(ibl_viewid, dis)
        w:remove(e)
    end

    local LUT_stage<const> = 0
    for e in w:select "LUT_builder material:in dispatch:in" do
        local dis = e.dispatch
        local mi = dis.material

        mi.s_LUT_write = icompute.create_image_property(IBL_INFO.LUT.value, LUT_stage, 0, "w")
        icompute.dispatch(ibl_viewid, dis)

        w:remove(e)
    end
end

local iibl = {}

function iibl.get_ibl()
    return IBL_INFO
end

function iibl.set_ibl_intensity(intensity)
    IBL_INFO.intensity = intensity
    update_ibl_param()
end

local function build_ibl_textures(ibl)
    local fmt = USE_RGB10A2 and "RGB10A2" or "RGBA16F"
    local function check_destroy(handle)
        if handle then
            bgfx.destroy(handle)
        end
    end

    IBL_INFO.intensity = ibl.intensity

    IBL_INFO.source.value = assert(ibl.source.value)
    IBL_INFO.source.facesize = assert(ibl.source.facesize)
    IBL_INFO.source.tex_name = ibl.source.tex_name

    if ibl.irradiance and (not irradianceSH_bandnum) then
        if ibl.irradiance.size ~= IBL_INFO.irradiance.size then
            IBL_INFO.irradiance.size = ibl.irradiance.size
            check_destroy(IBL_INFO.irradiance.value)

            IBL_INFO.irradiance.value = bgfx.create_texturecube(IBL_INFO.irradiance.size, false, 1, fmt, flags)
        end
    end

    if ibl.prefilter.size ~= IBL_INFO.prefilter.size then
        IBL_INFO.prefilter.size = ibl.prefilter.size
        check_destroy(IBL_INFO.prefilter.value)
        IBL_INFO.prefilter.value = bgfx.create_texturecube(IBL_INFO.prefilter.size, true, 1, fmt, cubemap_flags)
        IBL_INFO.prefilter.mipmap_count = math.log(ibl.prefilter.size, 2)+1
    end

    if ENABLE_IBL_LUT and ibl.LUT.size ~= IBL_INFO.LUT.size then
        IBL_INFO.LUT.size = ibl.LUT.size
        check_destroy(IBL_INFO.LUT.value)
        IBL_INFO.LUT.value = bgfx.create_texture2d(IBL_INFO.LUT.size, IBL_INFO.LUT.size, false, 1, "RG16F", flags)
    end
end


local function create_ibl_entities()
    create_prefilter_entities()

    if irradianceSH_bandnum then
        create_irradianceSH_entity()
    else
        create_irradiance_entity()
    end

    if ENABLE_IBL_LUT then
        create_LUT_entity()
    end
end

local function update_ibl_texture_info()
    imaterial.system_attrib_update("s_prefilter", IBL_INFO.prefilter.value)

    if not irradianceSH_bandnum then
        imaterial.system_attrib_update("s_irradiance", IBL_INFO.irradiance.value)
    end
    if ENABLE_IBL_LUT then
        imaterial.system_attrib_update("s_LUT", IBL_INFO.LUT.value)
    end
    update_ibl_param()
end

function ibl_sys:entity_init()
    for e in w:select "INIT ibl:in ibl_changed?out" do
        assetmgr.resource(e.ibl.source.tex_name)	-- request texture
        e.ibl_changed = true
    end
end

local function check_ibl_changed()
    for e in w:select "ibl_changed:update ibl:in" do
        local texid = assetmgr.resource(e.ibl.source.tex_name).id
        if not assetmgr.invalid_texture(texid) then
            local ibl = e.ibl
            e.ibl_changed = false
            ibl.source.value = texid
            build_ibl_textures(e.ibl)
            create_ibl_entities()
            update_ibl_texture_info()
        end
	end
end

function ibl_sys:data_changed()
    for _, enable in ibl_mb:unpack() do
        update_ibl_param(enable and 1.0 or 0.0)
    end

    for _ in exp_mb:each() do
        update_ibl_param()
    end

    check_ibl_changed()
end

return iibl
