local ecs   = ...
local world = ecs.world
local w     = world.w

local bgfx  = require "bgfx"
local di_sys = ecs.system "draw_indirect_system"

local layoutmgr = ecs.require "vertexlayout_mgr"

local INVALID_HANDLE_VALUE<const> = 0xffffffff

local function buffer_destroy(h)
    bgfx.destroy(h)
    return INVALID_HANDLE_VALUE
end

local function update_instance_buffer(e, instancememory, instancenum)
    local di = e.draw_indirect
    local ib = di.instance_buffer
    local iobj = e.indirect_object

    local function create_indirect_buffer(size)
        di.handle = bgfx.create_indirect_buffer(size)
        iobj.idb_handle = di.handle
    end

    if not di.handle then
        create_indirect_buffer(ib.size)
    else
        if instancenum > ib.size then
            ib.size = instancenum
            bgfx.destroy(di.handle)
            create_indirect_buffer(ib.size)
        end
    end

    if instancenum == 0 then
        -- not destroy ib.handle or di.handle
        iobj.draw_num, ib.num = 0, 0
    else
        --this memory can be release?
        ib.memory, ib.num = instancememory, instancenum
        if ib.handle then
            assert(iobj.itb_handle == ib.handle, "Invalid indirect_object")
            bgfx.update(ib.handle, 0, ib.memory)
        else
            --buffer use as instance buffer only should only create from bgfx.create_dynamic_vertex_buffer
            ib.handle = bgfx.create_dynamic_vertex_buffer(ib.memory, layoutmgr.get(ib.layout).handle, ib.flag)
            iobj.itb_handle = ib.handle
        end
        iobj.draw_num = ib.num
    end

    return true
end

function di_sys.component_init()
    for e in w:select "INIT draw_indirect:update indirect_object:update feature_set:in" do
        local ib = e.draw_indirect.instance_buffer
        update_instance_buffer(e, ib.memory, ib.num)
        e.feature_set.DRAW_INDIRECT = true
    end
end

function di_sys:entity_remove()
    for e in w:select "REMOVED draw_indirect:in indirect_object:update" do
        local io = e.indirect_object
        local di = e.draw_indirect
        di.instance_buffer.handle = buffer_destroy(di.instance_buffer.handle)
        di.handle = buffer_destroy(di.handle)

        io.itb_handle, io.idb_handle = INVALID_HANDLE_VALUE, INVALID_HANDLE_VALUE
        io.draw_num = 0
    end
end

local idi = {}

function idi.update_instance_buffer(e, instancememory, instancenum)
    w:extend(e, "draw_indirect:update indirect_object:update")
    if update_instance_buffer(e, instancememory, instancenum) then
        w:submit(e)
    end
end

function idi.instance_num(e)
    w:extend(e, "draw_indirect:in")
    return e.draw_indirect.instance_buffer.num
end

return idi