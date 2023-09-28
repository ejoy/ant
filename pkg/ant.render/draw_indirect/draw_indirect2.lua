local ecs   = ...
local world = ecs.world
local w     = world.w

local bgfx  = require "bgfx"
local di_sys = ecs.system "draw_indirect_system2"

local layoutmgr = ecs.require "vertexlayout_mgr"

function di_sys.component_init()
    for e in w:select "INIT draw_indirect:in indirect_object:update" do
        local di = e.draw_indirect
        local ib = di.instance_buffer
        ib.handle = bgfx.create_dynamic_vertex_buffer(ib.memory, layoutmgr.get(ib.layout).handle, ib.flag)
        di.handle = bgfx.create_indirect_buffer(ib.num)

        local io = e.indirect_object
        io.itb_handle = ib.handle
        io.idb_handle = di.handle
        io.draw_num = ib.num
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