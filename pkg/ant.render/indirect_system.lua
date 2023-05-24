local ecs = ...
local world = ecs.world
local w = world.w
local bgfx 			= require "bgfx"
local math3d = require "math3d"
local indirect_system = ecs.system "indirect_system"
local declmgr   = import_package "ant.render".declmgr
local icompute = ecs.import.interface "ant.render|icompute"
local assetmgr  = import_package "ant.asset"
local renderpkg = import_package "ant.render"
local viewidmgr = renderpkg.viewidmgr
local main_viewid = viewidmgr.get "csm_fb"
local indirect_material
local function get_instance_memory_buffer(indirect_info, instance_data_count)
    local indirect_num = #indirect_info
    local fmt<const> = "ffff"
    local memory_buffer = bgfx.memory_buffer(instance_data_count * 16 * indirect_num)
    local memory_buffer_offset = 1
    for indirect_idx = 1, indirect_num do
        local instance_data = indirect_info[indirect_idx]
        for data_idx = 1, #instance_data do
            memory_buffer[memory_buffer_offset] = fmt:pack(table.unpack(instance_data[data_idx]))
            memory_buffer_offset = memory_buffer_offset + 16
        end
    end
    return memory_buffer
end


local function create_indirect_compute(indirect_num, indirect_buffer, instance_buffer, instance_params, indirect_params)
    local dispatchsize = {
		math.floor((indirect_num - 1) / 64) + 1, 1, 1
	}
    local dis = { size = dispatchsize }
    local mo = indirect_material.object
    dis.material = mo:instance()
    local m = dis.material
    m.u_instance_params			= instance_params
    m.u_indirect_params         = indirect_params
    m.indirect_buffer           = indirect_buffer
    m.instance_buffer           = instance_buffer
	dis.fx = indirect_material._data.fx
    icompute.dispatch(main_viewid, dis)
end


function indirect_system:init()
    indirect_material = assetmgr.resource("/pkg/ant.resources/materials/indirect/indirect.material")
end

local function check_destroy(ro)
    if ro and ro.idb_handle ~= 0xffffffff then
        bgfx.destroy(ro.idb_handle)
    end
    if ro and ro.idb_handle ~= 0xffffffff then
        bgfx.destroy(ro.itb_handle)
    end
end

local function get_instance_data_count(instance_layout)
    local cnt = 0
    for v in string.gmatch(instance_layout, "|") do
        cnt = cnt + 1
    end
    return cnt + 1
end

local function update_indirect_buffer(e)
    check_destroy(e.render_object)
    local indirect_info = e.indirect.indirect_info
    local indirect_num = #indirect_info
    local instance_layout = e.indirect.instance_layout
    if indirect_num > 0 then
        local indirect_buffer = bgfx.create_indirect_buffer(indirect_num)
        local instance_data_count = get_instance_data_count(instance_layout)
        local instance_memory_buffer = get_instance_memory_buffer(indirect_info, instance_data_count)
        local instance_buffer = bgfx.create_dynamic_vertex_buffer(instance_memory_buffer, declmgr.get(instance_layout).handle, "r")
        local instance_params = math3d.vector(0, e.render_object.vb_num, 0, e.render_object.ib_num)
        local indirect_params = math3d.vector(indirect_num, 0, 0, 0)
        create_indirect_compute(indirect_num, indirect_buffer, instance_buffer, instance_params, indirect_params)
        e.render_object.idb_handle = indirect_buffer
        e.render_object.itb_handle = instance_buffer
        e.render_object.draw_num = indirect_num
    else
        e.render_object.idb_handle = 0xffffffff
        e.render_object.itb_handle = 0xffffffff
        e.render_object.draw_num = 0
    end
end

function indirect_system:data_changed()
    for e in w:select "indirect_update:update indirect:in render_object?update bounding:update" do
        update_indirect_buffer(e)
        e.bounding.aabb = math3d.aabb()
        e.indirect_update = nil
    end
end
