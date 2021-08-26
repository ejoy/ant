local ecs = ...
local world = ecs.world
local w = world.w

local bgfx = require "bgfx"
local math3d = require "math3d"

local renderpkg = import_package "ant.render"
local sampler = renderpkg.sampler
local viewidmgr = renderpkg.viewidmgr

local thread_group_size<const> = 8

local imaterial = world:interface "ant.asset|imaterial"

local ibl_sys = ecs.system "ibl_system"

local flags<const> = sampler.sampler_flag {
    MIN="LINEAR",
    MAG="LINEAR",
    U="CLAMP",
    V="CLAMP",
    BLIT="BLIT_COMPUTEWRITE",
}

local prefitlerflags<const> = sampler.sampler_flag {
    MIN="LINEAR",
    MAG="LINEAR",
    MIP="LINEAR",
    U="CLAMP",
    V="CLAMP",
    W="CLAMP",
    BLIT="BLIT_COMPUTEWRITE",
}

local ibl_textures = {
    irradiance   = {
        handle = nil, --bgfx.create_texturecube(irradiance_size, false, 1, "RGBA16F", flags),
        size = 0,
    },
    prefilter    = {
        handle = nil, --bgfx.create_texturecube(prefilter_size, true, 1, "RGBA16F", prefitlerflags),
        size = 0,
        mipmap_count = 0,
    },
    LUT             = {
        handle = nil, --bgfx.create_texture2d(LUT_size, LUT_size, false, 1, "RG16F", flags),
        size = 0,
    }
}

local icompute = world:interface "ant.render|icompute"

local ibl_viewid = viewidmgr.get "ibl"

local need_dispatch

local function create_irradiance_entity(ibl)
    local size = ibl.irradiance.size
    local dispatchsize = {
        size / thread_group_size, size / thread_group_size, 6
    }
    icompute.create_compute_entity(
        "irradiance_builder", "/pkg/ant.resources/materials/ibl/build_irradiance.material", dispatchsize)
end

local function create_prefilter_entities(ibl)
    local size = ibl.prefilter.size

    local mipmap_count = ibl.prefilter.mipmap_count
    local dr = 1 / (mipmap_count-1)
    local r = 0

    local function create_prefilter_compute_entity(dispatchsize, prefilter)
        w:reigster{name="prefilter_builder"}
        world:create_entity {
            policy = {
                "ant.render|compute_policy",
                "ant.render.ibl|prefilter",
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

    assert(math.abs(r-1.0) >= dr)
end

local function create_LUT_entity(ibl)
    local size = ibl.LUT.size
    local dispatchsize = {
        size / thread_group_size, size / thread_group_size, 1
    }
    local eid = icompute.create_compute_entity(
        "LUT_builder", "/pkg/ant.resources/materials/ibl/build_LUT.material", dispatchsize)
end

function ibl_sys:render_preprocess()
    if need_dispatch == nil then
        return
    end

    local source_tex = {stage = 0, texture={handle=ibl_textures.source.handle}}
    for e in w:select "INIT irradiance_builder dispatch:in" do
        local dis = e.dispatch
        local properties = dis.properties
        imaterial.set_property_directly(properties, "s_source", source_tex)
        properties.s_irradiance = icompute.create_image_property(ibl_textures.irradiance.handle, 1, 0, "w")
    
        if properties.u_build_ibl_param then
            local ip_v = properties.u_build_ibl_param.value
            ip_v.v = math3d.set_index(ip_v, 3, ibl_textures.irradiance.size)
        end

        icompute.dispatch(ibl_viewid, dis)\
        w:remove(e)
    end

    local prefilter_stage<const> = 1
    for e in w:select "INIT prefilter_builder dispatch:in prefilter:in" do
        local dis = e.dispatch
        local properties = dis.properties
        imaterial.set_property_directly(properties, "s_source", source_tex)

        local prefilter = e.prefilter
        local ip = properties.u_build_ibl_param
        if ip then
            local ipv = ip.value
            ipv.v = math3d.set_index(ipv, 3, prefilter.sample_count)
            ipv.v = math3d.set_index(ipv, 4, prefilter.roughness)
        end

        properties.s_prefilter = icompute.create_image_property(ibl_textures.prefilter.handle, prefilter_stage, prefilter.mipidx, "w")

        icompute.dispatch(ibl_viewid, dis)
        w:remove(e)
    end

    local LUT_stage<const> = 0
    for e in w:select "INIT LUT_builder dispatch:in" do
        local dis = e.dispatch
        local properties = dis.properties
        properties.s_LUT = icompute.create_image_property(ibl_textures.LUT.handle, LUT_stage, 0, "w")
        local ip = properties.u_build_ibl_param
        if ip then
            local ipv = ip.value
            ipv.v = math3d.set_index(ipv, 3, ibl_textures.LUT.size)
        end

        icompute.dispatch(ibl_viewid, dis)

        w:remove(e)
    end

    need_dispatch = nil
end

local iibl = ecs.interface "iibl"

function iibl.get_ibl()
    return ibl_textures
end

local function build_ibl_textures(ibl)
    local function check_destroy(handle)
        if handle then
            bgfx.destroy(handle)
        end
    end

    ibl_textures.source = ibl.source
    if ibl.irradiance.size ~= ibl_textures.irradiance.size then
        ibl_textures.irradiance.size = ibl.irradiance.size
        check_destroy(ibl_textures.irradiance.handle)

        ibl_textures.irradiance.handle = bgfx.create_texturecube(ibl_textures.irradiance.size, false, 1, "RGBA16F", flags)
    end

    if ibl.prefilter.size ~= ibl_textures.prefilter.size then
        ibl_textures.prefilter.size = ibl.prefilter.size
        check_destroy(ibl_textures.prefilter.handle)
        ibl_textures.prefilter.handle = bgfx.create_texturecube(ibl_textures.prefilter.size, true, 1, "RGBA16F", prefitlerflags)
        ibl_textures.prefilter.mipmap_count = ibl.prefilter.mipmap_count
    end

    if ibl.LUT.size ~= ibl_textures.LUT.size then
        ibl_textures.LUT.size = ibl.LUT.size
        check_destroy(ibl_textures.LUT.handle)
        ibl_textures.LUT.handle = bgfx.create_texture2d(ibl_textures.LUT.size, ibl_textures.LUT.size, false, 1, "RG16F", flags)
    end
end


local function create_ibl_entities(ibl)
    create_irradiance_entity(ibl)
    create_prefilter_entities(ibl)
    create_LUT_entity(ibl)
end

function iibl.filter_all(ibl)
    build_ibl_textures(ibl)
    create_ibl_entities(ibl)
    need_dispatch = true
end