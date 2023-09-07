local ecs = ...
local world = ecs.world
local w = world.w
local bgfx 			= require "bgfx"
local draw_indirect_system = ecs.system "draw_indirect_system"
local layoutmgr   = import_package "ant.render".layoutmgr
local math3d 	= require "math3d"
local icompute      = ecs.require "ant.render|compute.compute"
local hwi       = import_package "ant.hwi"
local FIRST_viewid<const> = hwi.viewid_get "csm_fb"

local idrawindirect = {}

local type_table = {
    ["ROAD"] = {1, 0, 0, 0},
    ["STONE_MOUNTAIN"] = {2, 0, 0, 0},
}

local function get_sm_worldmat(srt)
    local s, r, tx, tz = table.unpack(math3d.tovalue(srt))
    local rad = math.rad(r)
    local cosy, siny = math.cos(rad), math.sin(rad)
    local sm = math3d.matrix({
        s, 0, 0, 0,
        0, s, 0, 0,
        0, 0, s, 0,
        0, 0, 0, 1,
    })
    local rm = math3d.matrix({
        cosy, 0, siny, 0,
        0, 1, 0, 0,
        -siny, 0, cosy, 0,
        0, 0, 0, 1,
    })
    local tm = math3d.matrix({
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        tx, 0, tz, 1,
    })
    return math3d.mul(tm, math3d.mul(rm, sm))
end

local function get_road_worldmat(srt)
    local tx, ty, tz = math3d.index(srt, 1, 2, 3)
    return math3d.matrix({
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        tx, ty, tz, 1,
    })
end

local function get_obj_buffer(aabb_table, srt_table, mesh_idx_table, indirect_type, max_num)
    local memory_buffer = bgfx.memory_buffer(2 * 16 * max_num)
    local memory_table = {}
    for obj_idx, srt in pairs(srt_table) do
        local wm
        if indirect_type:match "stone_mountain" then
            wm = get_sm_worldmat(srt[1])
        elseif indirect_type:match "road" then
            wm = get_road_worldmat(srt[1])
        end
        local mesh_idx, mesh_idx_vector = 1, math3d.vector(0, 0, 0, 1)
        if mesh_idx_table then
            mesh_idx = math3d.index(mesh_idx_table[obj_idx], 4)
            mesh_idx_vector = mesh_idx_table[obj_idx]
        end
        local taabb = math3d.aabb_transform(wm, aabb_table[mesh_idx])
        local center, extent = math3d.aabb_center_extents(taabb)
        local aabb_min, aabb_max = math3d.sub(center, extent), math3d.add(center, extent)
        local obj_params = math3d.sub(math3d.add(aabb_min, mesh_idx_vector), math3d.vector(0, 0, 0, 1))
        memory_table[#memory_table+1] = math3d.serialize(obj_params)
        memory_table[#memory_table+1] = math3d.serialize(aabb_max)
    end
    memory_buffer[1] = table.concat(memory_table)
    return memory_buffer
end

local function get_instance_buffer(srt_info, max_num)
    local memory_buffer = bgfx.memory_buffer(3 * 16 * max_num)
    local memory_table = {}
    for _, srt in pairs(srt_info) do
        for data_idx = 1, 3 do
            memory_table[#memory_table+1] = math3d.serialize(srt[data_idx])
        end
    end
    memory_buffer[1] = table.concat(memory_table)
    return memory_buffer
end

local function get_indirect_params_buffer(indirect_params_table)
    local memory_buffer = bgfx.memory_buffer(16 * #indirect_params_table)
    local memory_table = {}
    for _, indirect_params in ipairs(indirect_params_table) do
        memory_table[#memory_table+1] = math3d.serialize(indirect_params)
    end
    memory_buffer[1] = table.concat(memory_table)
    return bgfx.create_dynamic_vertex_buffer(memory_buffer, layoutmgr.get("t43NIf").handle, "r")    
end

local function create_cull_dispatch(dispatch, obj_buffer, vib_handle, draw_num, plane_buffer)
    dispatch.size[1] = math.floor((draw_num - 1) / 64) + 1
    local m = dispatch.material
    m.b_visiblity_buffer = {
        type    = "b",
        value   = vib_handle,
        stage   = 0,
        access  = "w",
    }
    m.b_obj_buffer = {
        type    = "b",
        value   = obj_buffer,
        stage   = 1,
        access  = "r",
    }
    m.b_plane_buffer = {
        type    = "b",
        value   = plane_buffer,
        stage   = 2,
        access  = "r",
    }
end

local function create_queue_dispatch(dispatch, idb_handle, vib_handle, indirect_params_buffer, obj_buffer, queue_type, draw_num)
    dispatch.size[1] = math.floor(draw_num / 64) + 1
    local m = dispatch.material
    m.b_visibility_buffer = {
        type    = "b",
        value   = vib_handle,
        stage   = 0,
        access  = "r",
    }
    m.b_indirect_buffer = {
        type    = "b",
        value   = idb_handle,
        stage   = 1,
        access  = "w",
    }
    m.b_indirect_params_buffer = {
        type    = "b",
        value   = indirect_params_buffer,
        stage   = 2,
        access  = "r",
    }
    m.b_obj_buffer = {
        type    = "b",
        value   = obj_buffer,
        stage   = 3,
        access  = "r",
    }
    m.u_queue_params        = math3d.vector(queue_type, 0, 0, 0)
end

local function get_frustum_planes(queue_name)
    local select_tag = queue_name .. " camera_ref:in"
    local qe = w:first(select_tag)
    local ce <close> = world:entity(qe.camera_ref, "camera:in")
    return math3d.frustum_planes(ce.camera.viewprojmat)
end

local function update_plane_buffer()
    local memory_table = {}
    local memory_buffer = bgfx.memory_buffer(2 * 6 * 16)
    local planes_table = {
        get_frustum_planes("csm1_queue"),
        get_frustum_planes("main_queue")
    }
    for planes_idx = 1, #planes_table do
        local planes = planes_table[planes_idx]
        memory_table[#memory_table+1] = math3d.serialize(planes)
    end 
    memory_buffer[1] = table.concat(memory_table)
    return memory_buffer
end

function draw_indirect_system:entity_init()
    for e in w:select "INIT draw_indirect:update eid:in" do
        local di = e.draw_indirect
        local aabb_table, indirect_params_table, mesh_idx_table, srt_table, indirect_type, max_num = 
        di.aabb_table, di.indirect_params_table, di.mesh_idx_table, di.srt_table, di.indirect_type, di.max_num
        local instance_memory_buffer = get_instance_buffer(srt_table, max_num)
        local obj_memory_buffer = get_obj_buffer(aabb_table, srt_table, mesh_idx_table, indirect_type, max_num)
        di.itb_handle   = bgfx.create_dynamic_vertex_buffer(instance_memory_buffer, layoutmgr.get("t45NIf|t46NIf|t47NIf").handle, di.itb_flag)
        di.vib_handle   = bgfx.create_dynamic_vertex_buffer(max_num, layoutmgr.get("t40NIf").handle, "rw")
        di.idb_handle   = bgfx.create_indirect_buffer(max_num)
        di.obj_buffer   = bgfx.create_dynamic_vertex_buffer(obj_memory_buffer, layoutmgr.get("t41NIf").handle, "r") 
        di.plane_buffer = bgfx.create_dynamic_vertex_buffer(12, layoutmgr.get("t42NIf").handle, "r")
        di.indirect_params_buffer = get_indirect_params_buffer(indirect_params_table)
        local di_cull_id = world:create_entity {
            policy = {
                "ant.render|compute_policy",
            },
            data = {
                material    = "/pkg/ant.resources/materials/indirect/indirect_cull.material",
                dispatch    = {
                    size    = {0, 0, 0},
                },
                compute = true,
                draw_indirect_cull = {
                    draw_indirect_id = e.eid
                },
            }
        }
        local di_shadow_id = world:create_entity {
            policy = {
                "ant.render|compute_policy",
            },
            data = {
                material    = "/pkg/ant.resources/materials/indirect/indirect_queue.material",
                dispatch    = {
                    size    = {0, 0, 0},
                },
                compute = true,
                draw_indirect_queue = {
                    draw_indirect_id = e.eid,
                    queue_type = 0,
                    view_id = hwi.viewid_get "csm1"
                },
            }
        }
        local di_main_id = world:create_entity {
            policy = {
                "ant.render|compute_policy",
            },
            data = {
                material    = "/pkg/ant.resources/materials/indirect/indirect_queue.material",
                dispatch    = {
                    size    = {0, 0, 0},
                },
                compute = true,
                draw_indirect_queue = {
                    draw_indirect_id = e.eid,
                    queue_type = 1,
                    view_id = hwi.viewid_get "pre_depth"
                },
            }
        }
        di.di_cull_id   = di_cull_id
        di.di_shadow_id = di_shadow_id
        di.di_main_id   = di_main_id
        local te <close> = world:entity(di.target_eid, "draw_indirect_ready:update")
        te.draw_indirect_ready = true
    end

    for e in w:select "INIT draw_indirect_cull:in dispatch:in" do
        local di_eid = e.draw_indirect_cull.draw_indirect_id
        local die <close> = world:entity(di_eid, "draw_indirect:in")
        local di = die.draw_indirect
        local obj_buffer, plane_buffer, vib_handle, draw_num = di.obj_buffer, di.plane_buffer, di.vib_handle, di.draw_num
        create_cull_dispatch(e.dispatch, obj_buffer, vib_handle, draw_num, plane_buffer)
    end
    
    for e in w:select "INIT draw_indirect_queue:in dispatch:in" do
        local di_eid = e.draw_indirect_queue.draw_indirect_id
        local die <close> = world:entity(di_eid, "draw_indirect:in")
        local di = die.draw_indirect
        local idb_handle, vib_handle, indirect_params_buffer, obj_buffer, queue_type, draw_num = di.idb_handle, di.vib_handle, 
                                                                  di.indirect_params_buffer, di.obj_buffer, e.draw_indirect_queue.queue_type, di.draw_num
        create_queue_dispatch(e.dispatch, idb_handle, vib_handle, indirect_params_buffer, obj_buffer, queue_type, draw_num)
    end
end

function draw_indirect_system:data_changed()
    for e in w:select "draw_indirect:in" do
        local plane_buffer = e.draw_indirect.plane_buffer
        local plane_memory_buffer = update_plane_buffer()
        bgfx.update(plane_buffer, 0, plane_memory_buffer)
    end


    for e in w:select "draw_indirect_cull:in dispatch:in" do
        icompute.dispatch(FIRST_viewid, e.dispatch)
    end

    for e in w:select "draw_indirect_queue:in dispatch:in" do
        local viewid = e.draw_indirect_queue.view_id
        icompute.dispatch(viewid, e.dispatch)
    end
end

function draw_indirect_system:entity_remove()
    for e in w:select "REMOVED draw_indirect:update" do
        w:remove(e.stonemountain.draw_indirect.di_cull_id)
        w:remove(e.stonemountain.draw_indirect.di_shadow_id)
        w:remove(e.stonemountain.draw_indirect.di_main_id)
        if e.draw_indirect.itb_handle ~= 0xffffffff then
            bgfx.destroy(e.draw_indirect.itb_handle)
            e.draw_indirect.itb_handle = 0xffffffff
        end
        if e.draw_indirect.idb_handle ~= 0xffffffff then
            bgfx.destroy(e.draw_indirect.idb_handle)
            e.draw_indirect.idb_handle = 0xffffffff
        end
        if e.draw_indirect.vib_handle ~= 0xffffffff then
            bgfx.destroy(e.draw_indirect.vib_handle)
            e.draw_indirect.vib_handle = 0xffffffff
        end
        if e.draw_indirect.aabb_buffer ~= 0xffffffff then
            bgfx.destroy(e.draw_indirect.aabb_buffer)
            e.draw_indirect.aabb_buffer = 0xffffffff
        end
        if e.draw_indirect.plane_buffer ~= 0xffffffff then
            bgfx.destroy(e.draw_indirect.plane_buffer)
            e.draw_indirect.plane_buffer = 0xffffffff
        end
    end
end

function idrawindirect.get_draw_indirect_type(indirect_type)
    return type_table[indirect_type]
end

function idrawindirect.update_draw_indirect(e, die, srt_table)
    local di = die.draw_indirect
    local aabb_table, mesh_idx_table, indirect_type, max_num = di.aabb_table, di.mesh_idx_table, di.indirect_type, di.max_num
    local instance_memory_buffer = get_instance_buffer(srt_table, max_num)
    local obj_memory_buffer = get_obj_buffer(aabb_table, srt_table, mesh_idx_table, indirect_type, max_num)
    bgfx.update(di.itb_handle, 0, instance_memory_buffer)
    bgfx.update(di.obj_buffer, 0, obj_memory_buffer)
    di.draw_num = #srt_table
    e.render_object.draw_num = di.draw_num
end

return idrawindirect
