local ecs = ...
local world = ecs.world
local w = world.w
local bgfx = require "bgfx"

local ic = ecs.interface "icompute"

function ic.dispatch(viewid, ds)
	ds.material{}

	local s = ds.size
	bgfx.dispatch(viewid, ds.fx.prog, s[1], s[2], s[3])
end

function ic.create_compute_entity(name, materialfile, size, material_setting)
    ecs.create_entity {
        policy = {
            "ant.render|compute_policy",
            "ant.general|name",
        },
        data = {
            name        = name,
            material    = materialfile,
            material_setting = material_setting,
            dispatch    ={
                size    = size,
            },
            compute     = true,
            [name]      = true,
        }
    }
end

function ic.create_buffer_property(bufferdesc, which_stage)
    local stage = which_stage .. "_stage"
    local access = which_stage .. "_access"
    return {
        type    = "b",
        value  = bufferdesc.handle,
        stage   = bufferdesc[stage],
        access  = bufferdesc[access],
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

local cs = ecs.system "compute_system"
function cs:entity_init()
	for e in w:select "INIT material_result:in dispatch:in" do
		local mr = e.material_result
		local d = e.dispatch
        -- no state for compute shader
        d.material  = mr.material
        --TODO: need remove
		d.fx		= mr.fx
	end
end