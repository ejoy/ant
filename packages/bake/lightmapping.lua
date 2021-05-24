local ecs = ...
local world = ecs.world

local assetmgr = import_package "ant.asset"
local mathpkg = import_package "ant.math"
local renderpkg = import_package "ant.render"
local viewidmgr = renderpkg.viewidmgr

local mc = mathpkg.constant

local math3d = require "math3d"
local bgfx = require "bgfx"
local bake = require "bake"

local ipf = world:interface "ant.scene|iprimitive_filter"
local irender = world:interface "ant.render|irender"
local imaterial = world:interface "ant.asset|imaterial"

local lm_prim_trans = ecs.transform "lightmap_primitive_transform"
function lm_prim_trans.process_entity(e)
    local pf = e.primitive_filter
    pf.insert_item = function(filter, fxtype, eid, rc)
        local items = filter.result[fxtype].items
		if rc then
			rc.eid = eid
			ipf.add_item(items, eid, rc)
		else
			ipf.remove_item(items, eid)
		end
    end
end

local lm_trans = ecs.transform "lightmap_transform"
function lm_trans.process_entity(e)
    e._lightmap = {}
end

local lightmap_sys = ecs.system "lightmap_system"

local weight_downsample_material
local downsample_material

function lightmap_sys:init()
    weight_downsample_material = imaterial.load "/pkg/ant.bake/materials/weight_downsample.material"
    downsample_material = imaterial.load "/pkg/ant.bake/materials/downsample.material"

    world:create_entity {
        policy = {
            "ant.bake|lightmap",
            "ant.general|name",
        },
        data = {
            primitive_filter = {
                filter_type = "lightmap",
            },
            lightmap_tag = {},
        }
    }
end

local function load_geometry_info(item)
    
end

function lightmap_sys:end_frame()
    local ctx = bake.create_lightmap_context{
        size = 64,
        z_near = 0.1, z_far = 1,
        rgb = {1.0, 1.0, 1.0},
        interp_pass_count = 8, interp_threshold = 0.1,
        cam2surf_dis_modifier = 0.0,
    }

    local viewids = {
        viewidmgr.generate "weight_ds",
        viewidmgr.generate "ds",
    }

    local bake_viewid = viewids[1]

    local function find_uniform_handle(uniforms, name)
        for _, u in ipairs(uniforms) do
            if u.name == name then
                return u.handle
            end
        end
    end
    local wds_fx = weight_downsample_material.fx
    local ds_fx = downsample_material.fx

    ctx:set_shadering_info{
        viewids = viewids, 
        weight_downsample = {
            prog = 0xffff & wds_fx.prog,
            hemispheres = find_uniform_handle(wds_fx.uniforms, "hemispheres"),
            weights = find_uniform_handle(wds_fx.uniforms, "weights"),
        },
        downsample = {
            prog = 0xffff & ds_fx.prog,
            hemispheres = find_uniform_handle(ds_fx.uniforms, "hemispheres")
        }
    }

    local lm_e = world:singleton_entity "lightmap"

    local function save_lightmap()
    end

    for _, result in ipf.iter_filter(lm_e.primitive_filter) do
        for _, item in ipf.iter_target(result) do
            local e = world[item.eid]
            local lm = ctx:set_target_lightmap(e.lightmap)
            e._lightmap.data = lm

            repeat
                local finished, vp, view, proj = ctx:begin()
                if finished then
                    break
                end

                ctx:set_geometry{
                    worldmat = nil,
                    num = 0,
                    pos = {
                        data = nil,
                        type = "f",
                        stride = 0,
                    },
                    normal = {
                        type = "f",
                    },
                    uv = {
                        type = "f",
                    },
                    index = {
                        data = nil,
                        stride = 2, -- 2 or 4
                        type = "H"  --H or I
                    }
                }

                vp = math3d.tovalue(vp)
                bgfx.set_view_rect(bake_viewid, vp[1], vp[2], vp[3], vp[4])
                bgfx.set_view_transform(bake_viewid, view, proj)
                irender.draw(bake_viewid, item)
            until (true)

            lm:postprocess()
        end
    end
    
end

