local ecs = ...
local world = ecs.world
local w = world.w
local bgfx 			= require "bgfx"
local math3d = require "math3d"
local draw_indirect_system = ecs.system "draw_indirect_system"
local declmgr   = import_package "ant.render".declmgr
local idrawindirect = ecs.interface "idrawindirect"

local type_table = {
    ["ROAD"] = {1, 0, 0, 0},
    ["STONE_MOUNTAIN"] = {0, 1, 0, 0},
    ["HEAP_MESH"] = {0, 0, 1, 0}
}
function draw_indirect_system:entity_init()
    for e in w:select "INIT draw_indirect:update" do
        local max_num = e.draw_indirect.max_num
        e.draw_indirect.itb_handle = bgfx.create_dynamic_vertex_buffer(max_num, declmgr.get("t45NIf|t46NIf|t47NIf").handle, e.draw_indirect.itb_flag)
        e.draw_indirect.idb_handle = bgfx.create_indirect_buffer(max_num)
    end
end

function draw_indirect_system:entity_remove()
    for e in w:select "REMOVED draw_indirect:update" do
        if e.draw_indirect.itb_handle ~= 0xffffffff then
            bgfx.destroy(e.draw_indirect.itb_handle)
            e.draw_indirect.itb_handle = 0xffffffff
        end
        if e.draw_indirect.idb_handle ~= 0xffffffff then
            bgfx.destroy(e.draw_indirect.idb_handle)
            e.draw_indirect.idb_handle = 0xffffffff
        end
    end
end

function idrawindirect.get_draw_indirect_type(indirect_type)
    return type_table[indirect_type]
end