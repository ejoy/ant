local ecs   = ...
local world = ecs.world
local w     = world.w

local assetmgr  = import_package "ant.asset"
local RM        = ecs.require "ant.material|material"
local bgfx      = require "bgfx"

local ic = {}

local progman = require "programan.client"

function ic.dispatch(viewid, ds)
	ds.material()

	local s = ds.size
    assert(assetmgr.material_isvalid(ds.fx.prog), "Invalid compute program")
    if assetmgr.material_isvalid(ds.fx.prog) then
        bgfx.dispatch(viewid, progman.program_get(ds.fx.prog), s[1], s[2], s[3]) 
    end
end

function ic.create_compute_entity(name, materialfile, size, onready)
    return world:create_entity {
        policy = {
            "ant.render|compute",
        },
        data = {
            material    = materialfile,
            dispatch    ={
                size    = size,
            },
            on_ready    = onready,
            [name]      = true,
        }
    }
end

function ic.create_image_property(handle, stage, mip, access)
    return {
        type    = "i",
        value  = handle,
        stage   = stage,
        mip     = mip,
        access  = access
    }
end

local DEFAULT_DISPATCH_GROUP_SIZE_X<const>, DEFAULT_DISPATCH_GROUP_SIZE_Y<const> = 16, 16

function ic.calc_dispatch_size_2d_with_group_size(ww, hh, gx, gy, s)
    s[1], s[2] = (ww // gx)+1, (hh // gy)+1
end

function ic.calc_dispatch_size_2d(ww, hh, s)
    ic.calc_dispatch_size_2d_with_group_size(ww, hh, DEFAULT_DISPATCH_GROUP_SIZE_X, DEFAULT_DISPATCH_GROUP_SIZE_Y, s)
end

local cs = ecs.system "compute_system"
function cs:entity_init()
	for e in w:select "INIT material:in dispatch:in" do
        -- no state for compute shader
        local mr = assetmgr.resource(e.material)
        e.dispatch.material = RM.create_instance(mr.object)
        e.dispatch.fx       = mr.fx
	end
end

return ic
