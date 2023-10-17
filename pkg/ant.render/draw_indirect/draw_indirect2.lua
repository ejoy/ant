local ecs   = ...
local world = ecs.world
local w     = world.w

local bgfx  = require "bgfx"
local di_sys = ecs.system "draw_indirect_system2"

local layoutmgr = ecs.require "vertexlayout_mgr"

local function check_create_draw_indircet_buffer(io, ib)
    io.itb_handle = ib.handle

    if io.draw_num ~= ib.num then
        io.draw_num = ib.num
        io.idb_handle = bgfx.create_indirect_buffer(ib.num)
    end
    return io.idb_handle
end

local function update_instance_buffer(e)
    local di = e.draw_indirect
    local ib = di.instance_buffer
    if ib.handle and ib.dynamic then
        bgfx.update(ib.handle, 0, ib.memory)
    else
        --buffer use as instance buffer only should only create from bgfx.create_dynamic_vertex_buffer
        ib.handle = bgfx.create_dynamic_vertex_buffer(ib.memory, layoutmgr.get(ib.layout).handle, ib.flag)
    end

    di.handle = check_create_draw_indircet_buffer(e.indirect_object, ib)
end

function di_sys.component_init()
    for e in w:select "INIT draw_indirect:update indirect_object:update" do
        update_instance_buffer(e)
    end
end

local INVALID_HANDLE_VALUE<const> = 0xffffffff

local function buffer_destroy(h)
    bgfx.destroy(h)
    return INVALID_HANDLE_VALUE
end

function di_sys:entity_remove()
    for e in w:select "REMOVED draw_indirect:in indirect_object:update" do
        local io = e.indirect_object
        local di = e.draw_indirect
        di.ib.handle = buffer_destroy(di.ib.handle)
        di.handle = buffer_destroy(di.handle)

        io.itb_handle, io.idb_handle = INVALID_HANDLE_VALUE, INVALID_HANDLE_VALUE
        io.draw_num = 0
    end
end

local idi = {}

function idi.update_instance_buffer(e, instancememory, instancenum)
    w:extend(e, "draw_indirect:update indirect_object:update")
    local ib = e.draw_indirect.instance_buffer
    ib.memory, ib.num   = instancememory, instancenum
    update_instance_buffer(e)
end

return idi