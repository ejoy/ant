local ecs   = ...
local world = ecs.world
local w     = world.w

local common = ecs.require "common"
local util  = ecs.require "util"
local PC    = util.proxy_creator()
local icompute  = ecs.require "ant.render|compute.compute"
local dit_sys = common.test_system "draw_indirect"
local math3d  = require "math3d"
local hwi       = import_package "ant.hwi"
local main_viewid<const> = hwi.viewid_get "main_view"

local function dispatch_instance_buffer(e, diid, draw_num)

    local function to_dispath_num(indirectnum)
        return (indirectnum+63) // 64
    end

    local die = world:entity(diid, "draw_indirect:in mesh:in")
    local di = die.draw_indirect

   assert(di.instance_buffer.num == draw_num)
    if draw_num > 0 then
        local dis = e.dispatch
        dis.size[1] = to_dispath_num(draw_num)
        local m = dis.material
        die.draw_indirect.instance_buffer.params =  {draw_num, 0, 0, die.mesh.ib.num}
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

function dit_sys.init_world()
    local memory = {}
    local edge = 10
    local draw_num = math.tointeger( edge ^ 2 )
    local r = math3d.quaternion { axis = {1,0,0}, r = math.rad(60) }
    for i = 1, edge do
        for j = 1, edge do
            local t = math3d.vector(i, 0, j)
            local wm = math3d.matrix {s=0.1, r=r, t=t}
            wm = math3d.transpose(wm)
            local c1, c2, c3 = math3d.index(wm, 1, 2, 3)
            memory[#memory+1] = ("%s%s%s"):format(math3d.serialize(c1), math3d.serialize(c2), math3d.serialize(c3))
        end
    end

    local dieid = PC:create_entity {
        policy = {
            "ant.render|render",
            "ant.render|draw_indirect",
        },
        data = {
            scene = {},
            mesh = "/pkg/ant.resources.binary/meshes/base/cube.glb|meshes/Cube_P1.meshbin",
            material = "/pkg/ant.resources.binary/meshes/base/cube.glb|materials/Material.001.material",
            visible_state = "main_view|selectable",
            draw_indirect = {
                instance_buffer = {
                    memory  = table.concat(memory, ""),
                    flag    = "r",
                    layout  = "t45NIf|t46NIf|t47NIf",
                    num     = draw_num,
                },
            },
        },
    }

    local cid = PC:create_entity{
        policy = {
            "ant.render|compute",
        },
        data = {
            material = "/pkg/ant.test.features/assets/indirect_compute.material",
            dispatch = {
                size = {((draw_num+63)//64), 1, 1},
            },
            on_ready = function (e)
                w:extend(e, "dispatch:update")
                dispatch_instance_buffer(e, dieid, draw_num)
            end
        }
    }
end

function dit_sys:exit()
    PC:clear()
end