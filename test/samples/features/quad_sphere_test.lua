local ecs = ...
local world = ecs.world

local qst_sys = ecs.system "quad_sphere_test_system"
local iqs = world:interface "ant.quad_sphere|iquad_sphere"
local iom = world:interface "ant.objcontroller|obj_motion"
local icamera = world:interface "ant.camera|camera"

local math3d = require "math3d"

local qs_eid
function qst_sys:init()
    local trunk_num = 5
    qs_eid = iqs.create("test_quad_sphere", trunk_num, 100)
    local face = 3  --top
    local tx, ty = 4, 4
    local trunkid = face * trunk_num * trunk_num + ty * trunk_num + tx
    iqs.set_trunkid(qs_eid, trunkid)
end

local kb_mb = world:sub{"keyboard"}
function qst_sys:data_changed()
    
end

local lineeid
local cubeeids = {}
function qst_sys:follow_transform_updated()
    local mq = world:singleton_entity "main_queue"
    local cameraeid = mq.camera_eid
    for _, key, p, status in kb_mb:unpack() do
        if key == 'SPACE' and p == 0 then
            icamera.focus_obj(cameraeid, qs_eid)
        end

        if key == 'L' and p == 0 then
            if not status.SHIFT then
                lineeid = iqs.add_line_grid(qs_eid)
            else
                world:remove_entity(lineeid)
            end
        end

        if key == 'P' and p == 0 then
            local tilecenter = iqs.tile_center(qs_eid, {1, 1})
        
            local ceid = world:create_entity {
                policy = {
                    "ant.render|render",
                    "ant.general|name"
                },
                data = {
                    transform = {
                        s = 100,
                        t = math3d.tovalue(tilecenter),
                    },
                    material = "/pkg/ant.resources/materials/bunny.material",
                    mesh =  "/pkg/ant.resources.binary/meshes/base/cube.glb|meshes/pCube1_P1.meshbin",
                    state = 0x00000005,
                    scene_entity = true,
                    name = "qs_test_cube",
                }
            }
            cubeeids[#cubeeids+1] = ceid
        end
    end
end