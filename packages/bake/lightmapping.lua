local ecs = ...
local world = ecs.world

local mathpkg   = import_package "ant.math"
local renderpkg = import_package "ant.render"
local viewidmgr = renderpkg.viewidmgr
local declmgr   = renderpkg.declmgr

local math3d    = require "math3d"
local bgfx      = require "bgfx"
local bake      = require "bake"

local ipf       = world:interface "ant.scene|iprimitive_filter"
local irender   = world:interface "ant.render|irender"
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

local context_setting = {
    size = 64,
    z_near = 0.1, z_far = 1,
    rgb = {1.0, 1.0, 1.0},
    interp_pass_count = 8, interp_threshold = 0.1,
    cam2surf_dis_modifier = 0.0,
}

local weight_downsample_material
local downsample_material

local shading_info

local bake_ctx

local viewids<const> = {
    viewidmgr.generate "weight_ds",
    viewidmgr.generate "ds",
}

local bake_viewid<const> = viewids[1]

function lightmap_sys:init()
    weight_downsample_material = imaterial.load "/pkg/ant.bake/materials/weight_downsample.material"
    downsample_material = imaterial.load "/pkg/ant.bake/materials/downsample.material"

    local wds_fx = weight_downsample_material.fx
    local ds_fx = downsample_material.fx

    local function find_uniform_handle(uniforms, name)
        for _, u in ipairs(uniforms) do
            if u.name == name then
                return u.handle
            end
        end
    end

    shading_info = {
        viewids = viewids,
        weight_downsample = {
            prog        = 0xffff & wds_fx.prog,
            hemispheres = find_uniform_handle(wds_fx.uniforms,  "hemispheres"),
            weights     = find_uniform_handle(wds_fx.uniforms,  "weights"),
        },
        downsample = {
            prog        = 0xffff & ds_fx.prog,
            hemispheres = find_uniform_handle(ds_fx.uniforms, "hemispheres")
        }
    }

    world:create_entity {
        policy = {
            "ant.bake|lightmap",
            "ant.general|name",
        },
        data = {
            primitive_filter = {
                filter_type = "lightmap",
            },
            lightmap_baker = {},
        }
    }
end

local function load_geometry_info(item)
    local e = world[item.eid]
    local m = e.mesh
    local function get_type(t)
        local types<const> = {
            u = "B", i = "I", f = "f",
        }

        local tt = types[t]
        assert(tt, "invalid type")
        return types[tt]
    end
    local function get_attrib_item(name)
        for _, vb in ipairs(m.vb) do
            local offset = 0
            local declname = vb.declname
            for _, d in declname:gmatch "[^|]+" do
                if d:sub(1, 2):match(name) then
                    return {
                        offset = offset,
                        stride = declmgr.stride(declname),
                        memory = bgfx.memory_buffer(vb.memory),
                        type   = get_type(d:sub(6, 6)),
                    }
                end
                offset = offset + declmgr.elemsize(d)
            end
        end
    end

    local ib = m.ib
    local index
    if ib then
        local t<const> = ib.flag:match "d" and "H" or "I"
        index = {
            offset = 0,
            stride = t == "I" and 4 or 2,
            memory = bgfx.memory_buffer(ib.memory),
            type = t
        }
    end

    return {
        worldmat= math3d.pointer(item.worldmat),
        num     = m.vb.num,
        pos     = get_attrib_item "p",
        normal  = get_attrib_item "n",
        uv      = get_attrib_item "t1",
        index   = index,
    }
end

local function draw_scene(rq)
    for _, result in ipf.iter_filter(rq.primitive_filter) do
        for _, item in ipf.iter_target(result) do
            irender.draw(bake_viewid, item)
        end
    end
end

local function bake_entity(eid)
    local e = world[eid]
    if e == nil then
        return log.warn("invalid entity:%d", eid)
    end

    if e._lightmap == nil then
        return log.warn("entity %s not set any lightmap info will not be baked", e.name or "")
    end

    log.info("bake entity:%d, %s", eid, e.name or "")
    local lm = bake_ctx:set_target_lightmap(e.lightmap)
    e._lightmap.data = lm

    local g = load_geometry_info(e._rendercache)
    lm:set_geometry(g)
    local mq = world:singleton_entity "main_queue"
    log.info("begin bake entity:%d-%s", eid, e.name or "")
    repeat
        local finished, vp, view, proj = bake_ctx:begin_patch()
        if finished then
            break
        end

        vp = math3d.tovalue(vp)
        bgfx.set_view_rect(bake_viewid, vp[1], vp[2], vp[3], vp[4])
        bgfx.set_view_transform(bake_viewid, view, proj)
        draw_scene(mq)
        bake_ctx:end_patch()
        log.info("%d-%s process:%2f", eid, e.name or "", bake_ctx:process())
    until (true)

    log.info("bake finish for entity: %d-%s", eid, e.name or "")

    lm:postprocess()
    log.info("postprocess entity finish: %d-%s", eid, e.name or "")
end

local function bake_all()
    local lm_e = world:singleton_entity "lightmap_baker"
    for _, result in ipf.iter_filter(lm_e.primitive_filter) do
        for _, item in ipf.iter_target(result) do
            bake_entity(item.eid)
        end
    end
end

local bake_mb = world:sub{"bake"}
local lm_mb = world:sub{"component_register", "lightmap"}

local function init_bake_context(s)
    bake_ctx = bake.create_lightmap_context(s)
    bake_ctx:set_shadering_info(shading_info)
end

function lightmap_sys:end_frame()
    for msg in lm_mb:each() do
        init_bake_context(context_setting)
    end

    for msg in bake_mb:each() do
        assert(bake_ctx, "invalid bake context, need check")
        local eid = msg[2]
        if eid then
            bake_entity(eid)
        else
            log.info("bake entity scene with lightmap setting")
            bake_all()
        end
    end
end

