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

local lightmap_sys = ecs.system "lightmap_system"

local weight_downsample_material
local downsample_material

policy "lightmap"
.require_system "ant.bake|lightmap_system"
.require_transform "ant.bake|lightmap_primitive_transform"
.require_interface "ant.render|iprimitive_filter"
.component "primitive_filter"
.unique_component "lightmap_tag"

local lm_prim_trans = ecs.transform "lightmap_primitive_transform"
function lm_prim_trans.process_entity(e)

end

function lightmap_sys:init()
    weight_downsample_material = assetmgr.load_fx "/pkg/ant.reousrces/materials/lightmap/weight_downsample.material"
    downsample_material = assetmgr.load_fx "/pkg/ant.reousrces/materials/lightmap/downsample.material"

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

    ctx:set_shadering_info(viewids, 
        wds_fx.prog, find_uniform_handle(wds_fx.uniforms, "hemispheres"), find_uniform_handle(wds_fx.uniforms, "weights"),
        ds_fx.prog, find_uniform_handle(ds_fx.uniforms, "hemispheres"))

    local lm_e = world:singleton_entity "lightmap"

    local function save_lightmap()
    end

    for _, result in ipf.iter_filter(lm_e.primitive_filter) do
        for _, item in ipf.iter_target(result) do
            local e = world[item.eid]
            local lm = ctx:set_target_lightmap(e.lightmap)
            
            repeat
                local finished, vp, view, proj = ctx:begin()
                if finished then
                    break
                end

                vp = math3d.tovalue(vp)
                bgfx.set_view_rect(bake_viewid, vp[1], vp[2], vp[3], vp[4])
                bgfx.set_view_transform(bake_viewid, view, proj)
                irender.draw(bake_viewid, item)
            until (true)

            lm:postprocess()

            -- while (ctx:begin())do
                
            -- end
        end
    end
    
end

