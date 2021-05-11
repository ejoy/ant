local ecs = ...
local world = ecs.world

local bgfx = require "bgfx"
local math3d = require "math3d"

local renderpkg = import_package "ant.render"
local sampler = renderpkg.sampler
local viewidmgr = renderpkg.viewidmgr

local thread_group_size<const> = 8

local imaterial = world:interface "ant.asset|imaterial"

local init_ibl_trans = ecs.transform "init_ibl_transform"
function init_ibl_trans.process_entity(e)
    local ibl = e.ibl
    local irradiance_size    = ibl.irradiance.size
    local prefilter_size     = ibl.prefilter.size
    local LUT_size              = ibl.LUT.size

    local flags = sampler.sampler_flag {
        MIN="LINEAR",
        MAG="LINEAR",
        U="CLAMP",
        V="CLAMP",
        BLIT="BLIT_COMPUTEWRITE",
    }

    local prefitlerflags = sampler.sampler_flag {
        MIN="LINEAR",
        MAG="LINEAR",
        MIP="LINEAR",
        U="CLAMP",
        V="CLAMP",
        W="CLAMP",
        BLIT="BLIT_COMPUTEWRITE",
    }

    e._ibl = {
        source          = {
            handle = nil,
        },
        irradiance   = {
            handle = bgfx.create_texturecube(irradiance_size, false, 1, "RGBA16F", flags),
            size = irradiance_size,
        },
        prefilter    = {
            handle = bgfx.create_texturecube(prefilter_size, true, 1, "RGBA16F", prefitlerflags),
            size = prefilter_size,
            mipmap_count = math.log(prefilter_size, 2)+1,
        },
        LUT             = {
            handle = bgfx.create_texture2d(LUT_size, LUT_size, false, 1, "RG16F", flags),
            size = LUT_size,
        }
    }
end

local icompute = world:interface "ant.render|icompute"

local iibl = ecs.interface "iibl"

local ibl_viewid = viewidmgr.get "ibl"

local filter_entites

local function dispatch(eid)
    icompute.dispatch(ibl_viewid, world[eid]._rendercache)
end

local function create_irradiance_entity(ibl)
    local size = ibl.irradiance.size
    local dispatchsize = {
        size / thread_group_size, size / thread_group_size, 6
    }
    local eid = icompute.create_compute_entity(
        "irradiance_builder", "/pkg/ant.resources/materials/ibl/build_irradiance.material", dispatchsize)
    imaterial.set_property(eid, "s_source", {stage = 0, texture={handle=ibl.source.handle}})

    local e = world[eid]
    local properties = e._rendercache.properties
    properties.s_irradiance = icompute.create_image_property(ibl.irradiance.handle, 1, 0, "w")

    if properties.u_build_ibl_param then
        local ip_v = properties.u_build_ibl_param.value
        ip_v.v = math3d.set_index(ip_v, 3, ibl.irradiance.size)
    end
    return {
        eid = eid,
        name = "irradiance",
        dispatch = function (self)
            dispatch(self.eid)
        end,
        remove = function (self)
            world:remove_entity(self.eid)
        end
    }
end

local function create_prefilter_entity(ibl)
    local size = ibl.prefilter.size

    local mipmap_count = ibl.prefilter.mipmap_count
    local dr = 1 / (mipmap_count-1)
    local r = 0
    local eids = {}
    local source_tex = {stage = 0, texture={handle=ibl.source.handle}}
    local prefilter_stage<const> = 1
    for i=1, mipmap_count do
        local s = size >> (i-1)
        local dispatchsize = {
            math.floor(s / thread_group_size), math.floor(s / thread_group_size), 6
        }

        print("dispatchsize:", dispatchsize[1], dispatchsize[2], dispatchsize[3])
        local eid = icompute.create_compute_entity(
            "irradiance_builder", "/pkg/ant.resources/materials/ibl/build_prefilter.material", dispatchsize)

        imaterial.set_property(eid, "s_source", source_tex)
        local properties = world[eid]._rendercache.properties

        local ip = properties.u_build_ibl_param
        if ip then
            local ipv = ip.value
            ipv.v = math3d.set_index(ipv, 3, s)
            ipv.v = math3d.set_index(ipv, 4, r)
        end
        local mipidx = i-1
        properties.s_prefilter = icompute.create_image_property(ibl.prefilter.handle, prefilter_stage, mipidx, "w")
        eids[#eids+1] = eid
        r = r + dr
    end

    assert(math.abs(r-1.0) >= dr)
    return {
        eids = eids,
        name = "prefilter",
        dispatch = function (self)
            for _, eid in ipairs(self.eids) do
                dispatch(eid)
            end
        end,
        remove = function (self)
            for _, eid in ipairs(self.eids) do
                world:remove_entity(eid)
            end
        end
    }
end

local function create_LUT_entity(ibl)
    local size = ibl.LUT.size
    local dispatchsize = {
        size / thread_group_size, size / thread_group_size, 1
    }
    local eid = icompute.create_compute_entity(
        "irradiance_builder", "/pkg/ant.resources/materials/ibl/build_LUT.material", dispatchsize)

    local LUT_stage<const> = 0
    local properties = world[eid]._rendercache.properties
    properties.s_LUT = icompute.create_image_property(ibl.LUT.handle, LUT_stage, 0, "w")
    local ip = properties.u_build_ibl_param
    if ip then
        local ipv = ip.value
        ipv.v = math3d.set_index(ipv, 3, size)
    end

    return {
        eid = eid,
        name = "LUT",
        dispatch = function (self)
            dispatch(self.eid)
        end,
        remove = function(self)
            world:remove_entity(self.eid)
        end
    }
end

local function create_filter_entites(ibl)
    if filter_entites then
        for _, fe in pairs(filter_entites) do
            fe:remove()
        end
    end

    filter_entites = {
        create_irradiance_entity(ibl),
        create_prefilter_entity(ibl),
        create_LUT_entity(ibl),
    }
end

function iibl.filter_all(eid)
    local e = world[eid]
    local ibl = e._ibl

    create_filter_entites(ibl)

    for _, fe in pairs(filter_entites) do
        fe:dispatch()
    end
end