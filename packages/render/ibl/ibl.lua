local ecs = ...
local world = ecs.world
local w = world.w

local bgfx = require "bgfx"
local math3d = require "math3d"

local renderpkg = import_package "ant.render"
local sampler = renderpkg.sampler
local viewidmgr = renderpkg.viewidmgr

local icompute = ecs.import.interface "ant.render|icompute"
local iexposure = ecs.import.interface "ant.camera|iexposure"

local ibl_viewid = viewidmgr.get "ibl"

local thread_group_size<const> = 8

local imaterial = ecs.import.interface "ant.asset|imaterial"

local ibl_sys = ecs.system "ibl_system"

local flags<const> = sampler.sampler_flag {
    MIN="LINEAR",
    MAG="LINEAR",
    U="CLAMP",
    V="CLAMP",
    BLIT="BLIT_COMPUTEWRITE",
}

local cubemap_flags<const> = sampler.sampler_flag {
    MIN="LINEAR",
    MAG="LINEAR",
    MIP="LINEAR",
    U="CLAMP",
    V="CLAMP",
    W="CLAMP",
    BLIT="BLIT_COMPUTEWRITE",
}

local ibl_textures = {
    source = {facesize = 0, stage=0, value=nil},
    irradiance   = {
        value = nil,
        size = 0,
    },
    prefilter    = {
        value = nil,
        size = 0,
        mipmap_count = 0,
    },
    LUT             = {
        value = nil,
        size = 0,
    }
}

local function create_irradiance_entity(ibl)
    local size = ibl_textures.irradiance.size
    local dispatchsize = {
        size / thread_group_size, size / thread_group_size, 6
    }
    icompute.create_compute_entity(
        "irradiance_builder", "/pkg/ant.resources/materials/ibl/build_irradiance.material", dispatchsize)
end

local function create_prefilter_entities(ibl)
    local size = ibl_textures.prefilter.size

    local mipmap_count = ibl_textures.prefilter.mipmap_count
    local dr = 1 / (mipmap_count-1)
    local r = 0

    local function create_prefilter_compute_entity(dispatchsize, prefilter)
        ecs.create_entity {
            policy = {
                "ant.render|compute_policy",
                "ant.render|prefilter",
                "ant.general|name",
            },
            data = {
                name        = "prefilter_builder",
                material    = "/pkg/ant.resources/materials/ibl/build_prefilter.material",
                dispatch    ={
                    size    = dispatchsize,
                },
                prefilter = prefilter,
                compute     = true,
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
    local size = ibl_textures.LUT.size
    local dispatchsize = {
        size / thread_group_size, size / thread_group_size, 1
    }
   icompute.create_compute_entity(
        "LUT_builder", "/pkg/ant.resources/materials/ibl/build_LUT.material", dispatchsize)
end

local ibl_mb = world:sub{"ibl_changed"}
local exp_mb = world:sub{"exposure_changed"}

local function update_ibl_param(intensity)
    local sa = imaterial.system_attribs()
    local mq = w:singleton("main_queue", "camera_ref:in")
    local ce = world:entity(mq.camera_ref)
    local ev = iexposure.exposure(ce)

    intensity = intensity or 1
    intensity = intensity * ibl_textures.intensity * ev
    sa:update("u_ibl_param", math3d.vector(ibl_textures.prefilter.mipmap_count, intensity, 0.0 ,0.0))
end

function ibl_sys:data_changed()
    for _, enable in ibl_mb:unpack() do
        update_ibl_param(enable and 1.0 or 0.0)
    end

    for _ in exp_mb:each() do
        update_ibl_param()
    end
end

local sample_count<const> = 512

function ibl_sys:render_preprocess()
    local source_tex = ibl_textures.source
    for e in w:select "irradiance_builder dispatch:in" do
        local dis = e.dispatch
        local material = dis.material
        material.s_source = source_tex
        material.u_build_ibl_param = math3d.vector(sample_count, 0, ibl_textures.source.facesize, 0.0)

        -- there no binding attrib in material, but we just use this entity only once
        local mobj = material:get_material()
        mobj:set_attrib("s_irradiance", icompute.create_image_property(ibl_textures.irradiance.value, 1, 0, "w"))

        icompute.dispatch(ibl_viewid, dis)
        w:remove(e)
    end

    local registered
    for e in w:select "prefilter_builder dispatch:in prefilter:in" do
        local dis = e.dispatch
        local material = dis.material
        local prefilter_stage<const> = 1
        if registered == nil then
            local matobj = material:get_material()
            matobj:set_attrib("s_prefilter", {type='i', mip=0, access='w', stage=prefilter_stage})
            registered = true
        end

        material.s_source = source_tex
        local prefilter = e.prefilter
        material.u_build_ibl_param = math3d.vector(sample_count, 0, ibl_textures.source.facesize, prefilter.roughness)
        material.s_prefilter = icompute.create_image_property(ibl_textures.prefilter.value, prefilter_stage, prefilter.mipidx, "w")

        icompute.dispatch(ibl_viewid, dis)
        w:remove(e)
    end

    local LUT_stage<const> = 0
    for e in w:select "LUT_builder dispatch:in" do
        local dis = e.dispatch
        local material = dis.material
        local matobj = material:get_material()
        matobj:set_attrib("s_LUT", icompute.create_image_property(ibl_textures.LUT.value, LUT_stage, 0, "w"))
        icompute.dispatch(ibl_viewid, dis)

        w:remove(e)
    end
end

local iibl = ecs.interface "iibl"

function iibl.get_ibl()
    return ibl_textures
end

function iibl.set_ibl_intensity(intensity)
    ibl_textures.intensity = intensity
    update_ibl_param()
end

local function build_ibl_textures(ibl)
    local function check_destroy(handle)
        if handle then
            bgfx.destroy(handle)
        end
    end

    ibl_textures.intensity = ibl.intensity

    ibl_textures.source.value = assert(ibl.source.value)
    ibl_textures.source.facesize = assert(ibl.source.facesize)

    if ibl.irradiance.size ~= ibl_textures.irradiance.size then
        ibl_textures.irradiance.size = ibl.irradiance.size
        check_destroy(ibl_textures.irradiance.value)

        ibl_textures.irradiance.value = bgfx.create_texturecube(ibl_textures.irradiance.size, false, 1, "RGBA16F", flags)
    end

    if ibl.prefilter.size ~= ibl_textures.prefilter.size then
        ibl_textures.prefilter.size = ibl.prefilter.size
        check_destroy(ibl_textures.prefilter.value)
        ibl_textures.prefilter.value = bgfx.create_texturecube(ibl_textures.prefilter.size, true, 1, "RGBA16F", cubemap_flags)
        ibl_textures.prefilter.mipmap_count = math.log(ibl.prefilter.size, 2)+1
    end

    if ibl.LUT.size ~= ibl_textures.LUT.size then
        ibl_textures.LUT.size = ibl.LUT.size
        check_destroy(ibl_textures.LUT.value)
        ibl_textures.LUT.value = bgfx.create_texture2d(ibl_textures.LUT.size, ibl_textures.LUT.size, false, 1, "RG16F", flags)
    end
end


local function create_ibl_entities(ibl)
    create_irradiance_entity(ibl)
    create_prefilter_entities(ibl)
    create_LUT_entity()
end

local function update_ibl_texture_info()
    local sa = imaterial.system_attribs()
    sa:update("s_irradiance", ibl_textures.irradiance.value)
    sa:update("s_prefilter", ibl_textures.prefilter.value)
    sa:update("s_LUT",  ibl_textures.LUT.value)

    update_ibl_param()
end

function iibl.filter_all(ibl)
    build_ibl_textures(ibl)
    create_ibl_entities(ibl)

    update_ibl_texture_info()
end