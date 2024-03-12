local ecs   = ...
local world = ecs.world
local w     = world.w
local math3d = require "math3d"
local datalist  = require "datalist"
local ie_sys = ecs.system "indirect_entity_system"
local aio       = import_package "ant.io"
local icompute  = ecs.require "ant.render|compute.compute"
local INDIRECT_MATERIAL<const> = "/pkg/ant.resources/materials/hitch/hitch_compute.material"
local DEFAULT_SIZE<const> = 50
local hwi       = import_package "ant.hwi"
local main_viewid<const> = hwi.viewid_get "main_view"
local idi       = ecs.require "ant.render|draw_indirect.draw_indirect"


local function build_instance_buffer(srts)
    if not srts then return end
    local memory = {}
    for _, srt in ipairs(srts) do
        local wm = math3d.matrix {s = srt.s, r = srt.r, t = srt.t}
        wm = math3d.transpose(wm)
        local c1, c2, c3 = math3d.index(wm, 1, 2, 3)
        memory[#memory+1] = ("%s%s%s"):format(math3d.serialize(c1), math3d.serialize(c2), math3d.serialize(c3))
    end
    
    return table.concat(memory, "")
end

local function to_dispatch_num(draw_num)
    return (draw_num+63) // 64
end

local function dispatch_compute_entity(e, dieid)

    local die = world:entity(dieid, "draw_indirect:in")
    local di = die.draw_indirect
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

local function create_draw_indirect_entity(ie)
    local memory = build_instance_buffer(ie.srts)
    local ib_num = datalist.parse(aio.readall(ie.mesh)).ib.num
    local draw_num = #ie.srts
    return world:create_entity {
        group = ie.gid,
        policy = {
            "ant.render|render",
            "ant.render|draw_indirect",
        },
        data = {
            scene       = {},
            mesh        = ie.mesh,
            material    = ie.material,
            visible     = ie.visible,
            visible_masks = ie.visible_masks,
            render_layer = ie.render_layer,
            draw_indirect = {
                instance_buffer = {
                    memory  = memory,
                    flag    = "ra",
                    layout  = "t45NIf|t46NIf|t47NIf",
                    num     = draw_num,
                    size    = draw_num > DEFAULT_SIZE and draw_num * 2 or DEFAULT_SIZE,
                    params =  {draw_num, 0, 0, ib_num}
                },
            },
        }
    }
end

local function create_compute_entity(dieid, draw_num)
    return world:create_entity{
        policy = {
            "ant.render|compute",
        },
        data = {
            material = INDIRECT_MATERIAL,
            dispatch = {
                size = {to_dispatch_num(draw_num), 1, 1},
            },
            on_ready = function (e)
                w:extend(e, "dispatch:update")
                dispatch_compute_entity(e, dieid)
            end
        }
    }
end

local function update_draw_indirect_entity(dieid, srts)
    local memory = build_instance_buffer(srts)
    local draw_num = #srts
    local die = world:entity(dieid, "draw_indirect:in")
    local di = die.draw_indirect
    di.instance_buffer.params[1] = draw_num
    idi.update_instance_buffer(die, memory, draw_num)
end

local function update_compute_entity(ceid, dieid)
    local ce = world:entity(ceid, "dispatch:update")
    dispatch_compute_entity(ce, dieid)

end

function ie_sys:entity_init()
    for e in w:select "INIT indirect_entity:in" do
        local ie = e.indirect_entity
        local draw_num = #assert(ie.srts, "Invalid indirect_entity, need srts")
        local dieid = create_draw_indirect_entity(ie)
        local ceid  = create_compute_entity(dieid, draw_num)
        ie.dieid, ie.ceid = dieid, ceid
    end
end

function ie_sys:data_changed()
    for e in w:select "indirect_update:update indirect_entity:in" do
        local ie = e.indirect_entity
        local dieid, ceid, srts = ie.dieid, ie.ceid, ie.srts
        update_draw_indirect_entity(dieid, srts)
        update_compute_entity(ceid, dieid)
        e.indirect_update = false
    end
end

function ie_sys:entity_remove()
    for e in w:select "REMOVED indirect_entity:in" do
        local ie = e.indirect_entity
        local dieid, ceid = ie.dieid, ie.ceid
        w:remove(dieid)
        w:remove(ceid)
    end
end