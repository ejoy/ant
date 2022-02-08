local ecs = ...
local world = ecs.world
local w = world.w

local bgfx = require "bgfx"
local math3d = require "math3d"

local renderpkg = import_package "ant.render"
local sampler = renderpkg.sampler
local viewidmgr = renderpkg.viewidmgr

local icompute = ecs.import.interface "ant.render|icompute"
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
    source = {stage=0, texture={handle=nil}},
    cubemap_source = {stage=0, texture={handle=nil}},
    irradiance   = {
        handle = nil,
        size = 0,
    },
    prefilter    = {
        handle = nil,
        size = 0,
        mipmap_count = 0,
    },
    LUT             = {
        handle = nil,
        size = 0,
    }
}

local function create_cvt2cubemap_entities(ibl)
    if ibl.cubemap then
        return
    end

    local size = ibl_textures.cubemap_source.size
    local mipmap_count = math.log(size, 2)+1
    for i=1, mipmap_count do
        local s = size >> (i-1)
        local dispatchsize = {
            math.floor(s / thread_group_size), math.floor(s / thread_group_size), 6
        }
    
        ecs.create_entity {
            policy = {
                "ant.render|compute_policy",
                "ant.render|panorama2cubemap_converter",
                "ant.general|name",
            },
            data = {
                name        = "panorama2cubemap_converter",
                material    = "/pkg/ant.resources/materials/panorama2cubemap.material",
                dispatch    ={
                    size    = dispatchsize,
                    sample_lod = i-1,
                },
                compute     = true,
                panorama2cubemap_converter = true,
            }
        }
    end
end

local function create_irradiance_entity(ibl)
    local size = ibl_textures.irradiance.size
    local dispatchsize = {
        size / thread_group_size, size / thread_group_size, 6
    }

    local setting = ibl.source.cubemap and {CUBEMAP_SOURCE=1} or nil

    icompute.create_compute_entity(
        "irradiance_builder", "/pkg/ant.resources/materials/ibl/build_irradiance.material", dispatchsize, setting)
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
                material_setting = ibl.source.cubemap and {CUBEMAP_SOURCE=1} or nil,
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

function ibl_sys:render_preprocess()
    -- local set_source
    -- for e in w:select "panorama2cubemap_converter dispatch:in" do
    --     local dis = e.dispatch
    --     local properties = dis.properties
    --     imaterial.set_property_directly(properties, "s_source", ibl_textures.source)

    --     local p = properties.u_param.value
    --     local size = dis.size
    --     p.v = math3d.set_index(p, 1, dis.sample_lod, size[1]*thread_group_size, size[2]*thread_group_size)

    --     local cubemap_source_stage<const> = 1
    --     properties.s_cubemap_source = icompute.create_image_property(ibl_textures.cubemap_source.texture.handle, cubemap_source_stage, dis.sample_lod, "w")
    --     icompute.dispatch(ibl_viewid, dis)
    --     w:remove(e)
    --     set_source = true
    -- end

    -- if set_source then
    --     ibl_textures.source = ibl_textures.cubemap_source
    -- end

    local source_tex = ibl_textures.source
    for e in w:select "irradiance_builder dispatch:in" do
        local dis = e.dispatch
        local properties = dis.properties
        imaterial.set_property_directly(properties, "s_source", source_tex)
        properties.s_irradiance = icompute.create_image_property(ibl_textures.irradiance.handle, 1, 0, "w")
    
        if properties.u_build_ibl_param then
            local ip_v = properties.u_build_ibl_param.value
            ip_v.v = math3d.set_index(ip_v, 3, ibl_textures.irradiance.size)
        end

        icompute.dispatch(ibl_viewid, dis)
        w:remove(e)
    end

    for e in w:select "prefilter_builder dispatch:in prefilter:in" do
        local dis = e.dispatch
        local properties = dis.properties
        imaterial.set_property_directly(properties, "s_source", source_tex)

        local prefilter = e.prefilter
        local ip = properties.u_build_ibl_param
        if ip then
            local ipv = ip.value
            ipv.v = math3d.set_index(ipv, 3, prefilter.sample_count, prefilter.roughness)
        end
        local prefilter_stage<const> = 1
        properties.s_prefilter = icompute.create_image_property(ibl_textures.prefilter.handle, prefilter_stage, prefilter.mipidx, "w")

        icompute.dispatch(ibl_viewid, dis)
        w:remove(e)
    end

    local LUT_stage<const> = 0
    for e in w:select "LUT_builder dispatch:in" do
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

    ibl_textures.intensity = ibl.intensity

    --TODO: make irradiance as 2D map and use RGB8E format to store
    ibl_textures.source.texture.handle = ibl.source.handle
    -- if not ibl.cubemap then
    --     ibl_textures.cubemap_source.size = 512
    --     check_destroy(ibl_textures.cubemap_source.texture.handle)
    --     ibl_textures.cubemap_source.texture.handle = bgfx.create_texturecube(ibl_textures.cubemap_source.size, true, 1, "RGBA16F", cubemap_flags)
    -- end

    if ibl.irradiance.size ~= ibl_textures.irradiance.size then
        ibl_textures.irradiance.size = ibl.irradiance.size
        check_destroy(ibl_textures.irradiance.handle)

        ibl_textures.irradiance.handle = bgfx.create_texturecube(ibl_textures.irradiance.size, false, 1, "RGBA16F", flags)
    end

    if ibl.prefilter.size ~= ibl_textures.prefilter.size then
        ibl_textures.prefilter.size = ibl.prefilter.size
        check_destroy(ibl_textures.prefilter.handle)
        ibl_textures.prefilter.handle = bgfx.create_texturecube(ibl_textures.prefilter.size, true, 1, "RGBA16F", cubemap_flags)
        ibl_textures.prefilter.mipmap_count = math.log(ibl.prefilter.size, 2)+1
    end

    if ibl.LUT.size ~= ibl_textures.LUT.size then
        ibl_textures.LUT.size = ibl.LUT.size
        check_destroy(ibl_textures.LUT.handle)
        ibl_textures.LUT.handle = bgfx.create_texture2d(ibl_textures.LUT.size, ibl_textures.LUT.size, false, 1, "RG16F", flags)
    end
end


local function create_ibl_entities(ibl)
    --create_cvt2cubemap_entities(ibl)
    create_irradiance_entity(ibl)
    create_prefilter_entities(ibl)
    create_LUT_entity()
end

function iibl.filter_all(ibl)
    build_ibl_textures(ibl)
    create_ibl_entities(ibl)
end