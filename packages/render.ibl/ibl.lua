local ecs = ...
local world = ecs.world

local bgfx = require "bgfx"

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

    local fmt<const> = "RGBA16F"
    local flags = sampler.sampler_flag {
        MIN="LINEAR",
        MAG="LINEAR",
        U="CLAMP",
        V="CLAMP",
    }

    local prefitlerflags = sampler.sampler_flag {
        MIN="LINEAR",
        MAG="LINEAR",
        MIP="LINEAR",
        U="CLAMP",
        V="CLAMP",
        W="CLAMP",
    }

    e._ibl = {
        source          = {
            handle = nil,
        },
        irradiance   = {
            handle = bgfx.create_texturecube(irradiance_size, false, 1, fmt, flags),
            size = irradiance_size,
        },
        prefilter    = {
            handle = bgfx.create_texturecube(prefilter_size, true, 1, fmt, prefitlerflags),
            size = prefilter_size,
        },
        LUT             = {
            handle = bgfx.create_texture2d(LUT_size, LUT_size, false, 1, fmt, flags),
            size = LUT_size,
        }
    }
end

local icompute = world:interface "ant.render|icompute"

local iibl = ecs.interface "iibl"

local ibl_viewid = viewidmgr.get "ibl"

local function fitler_irradiance_map(ibl)
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

    icompute.dispatch(ibl_viewid, e._rendercache)
end

local function filter_prefilter_map(ibl)

end

local function build_LUT_map(ibl)

end

function iibl.filter_all(eid)
    local e = world[eid]
    local ibl = e._ibl
    fitler_irradiance_map(ibl)
    filter_prefilter_map(ibl)
    filter_prefilter_map(ibl)
end