local ecs       = ...
local world     = ecs.world
local w         = world.w

local bgfx      = require "bgfx"
local math3d    = require "math3d"
local datalist  = require "datalist"

local assetmgr  = import_package "ant.asset"
local renderpkg = import_package "ant.render"
local sampler   = renderpkg.sampler

local hwi       = import_package "ant.hwi"
local aio       = import_package "ant.io"
local imaterial = ecs.require "ant.asset|material"
local icompute  = ecs.require "ant.render|compute.compute"
local viewid<const> = hwi.viewid_get "csm_fb"

local thread_group_size<const> = 8

local ds_sys = ecs.system "direct_specular_system"

local flags<const> = sampler {
    MIN="LINEAR",
    MAG="LINEAR",
    U="CLAMP",
    V="CLAMP",
    BLIT="BLIT_COMPUTEWRITE",
}

local function update_system_texture_info(texture_handle)
    imaterial.system_attrib_update("s_direct_specular", texture_handle)
end

local function mark_prog(e)
    assetmgr.material_mark(e.dispatch.fx.prog)
end

local function dispatch_prog(e, handle)
    local dis = e.dispatch
    local mi = dis.material
    mi.s_LUT_write = icompute.create_image_property(handle, 0, 0, "w")
    icompute.dispatch(viewid, dis)
end

local function create_compute_entity(ds)
    local dx, dy, mat = ds.sample_size.dot, ds.sample_size.roughness, ds.material
    local dispatchsize = {
        dx / thread_group_size, dy / thread_group_size, 1
    }
    local function on_ready(e)
        w:extend(e, "dispatch:in")
        --mark_prog(e)
        dispatch_prog(e, ds.value)
        w:remove(e)
        update_system_texture_info(ds.value)
    end
   icompute.create_compute_entity(
        "direct_specular_builder", mat, dispatchsize, on_ready)
end

function ds_sys:entity_init()
    for e in w:select "INIT direct_specular:in" do
        local ds = e.direct_specular
        local dx, dy = ds.sample_size.dot, ds.sample_size.roughness
        ds.value = bgfx.create_texture2d(dx, dy, false, 1, "RGBA16F", flags)
        create_compute_entity(ds)
    end
end

