local ecs   = ...
local world = ecs.world
local w     = world.w
local math3d = require "math3d"
local ie_sys = ecs.system "indirect_entity_system"
local icompute  = ecs.require "ant.render|compute.compute"
local INDIRECT_MATERIAL<const> = "/pkg/ant.resources/materials/hitch/hitch_compute.material"
local hwi       = import_package "ant.hwi"
local main_viewid<const> = hwi.viewid_get "main_view"
local idi       = ecs.require "ant.render|draw_indirect.draw_indirect"
local assetmgr  = import_package "ant.asset"

local ie = {}

local function build_instance_buffer(srts)
    if not srts then return end
    local memory = {}
    local draw_num = 0
    for _, srt in pairs(srts) do
        local wm = math3d.matrix {s = srt.s, r = srt.r, t = srt.t}
        wm = math3d.transpose(wm)
        local c1, c2, c3 = math3d.index(wm, 1, 2, 3)
        memory[#memory+1] = ("%s%s%s"):format(math3d.serialize(c1), math3d.serialize(c2), math3d.serialize(c3))
        draw_num = draw_num + 1
    end
    
    return table.concat(memory, ""), draw_num
end

local function to_dispatch_num(draw_num)
    return (draw_num+63) // 64
end

local function dispatch_compute_entity(e, di)
    local draw_num = di.instance_buffer.params[1]
    if draw_num > 0 then
        local dis = e.dispatch
        dis.size[1] = to_dispatch_num(draw_num)
        local m = dis.material
        m.u_mesh_params = math3d.vector(di.instance_buffer.params)
        m.b_indirect_buffer = {
            type = "b",
            access = "w",
            value = di.handle,
            stage = 0,
        }
        icompute.dispatch(main_viewid, dis)
    end
end

local function create_compute_entity()
    return world:create_entity{
        policy = {
            "ant.render|compute",
        },
        data = {
            material = INDIRECT_MATERIAL,
            dispatch = {
                size = {1, 1, 1},
            },
            on_ready = function (e)
                w:extend(e, "dispatch:update")
                assetmgr.material_mark(e.dispatch.fx.prog)
            end
        }
    }
end

function ie.add(eid, srt)
    local die = world:entity(eid, "draw_indirect:in draw_indirect_update?out")
    local di = die.draw_indirect
    local idx = di.srt_idx
    di.srts[di.idx] = srt
    di.srt_idx = di.srt_idx + 1
    die.draw_indirect_update = true
    return idx
end

function ie.mod(eid, idx, srt)
    local die = world:entity(eid, "draw_indirect:in draw_indirect_update?out")
    local di = die.draw_indirect
    di.srts[idx] = srt
    die.draw_indirect_update = true
end

function ie_sys:entity_init()
    for e in w:select "INIT draw_indirect:in" do
        e.draw_indirect.ceid = create_compute_entity()
        e.draw_indirect.srts = {}
        e.draw_indirect.srt_idx = 1
    end
end

function ie_sys:data_changed()
    for e in w:select "draw_indirect_update:update draw_indirect:in" do
        local di = e.draw_indirect
        local ceid, srts = di.dieid, di.srts
        local ce = world:entity(ceid, "dispatch:update")

        local memory, draw_num = build_instance_buffer(srts)
        di.instance_buffer.params[1] = draw_num
        idi.update_instance_buffer(e, memory, draw_num)

        dispatch_compute_entity(ce, di)

        e.draw_indirect_update = false
    end
end

return ie