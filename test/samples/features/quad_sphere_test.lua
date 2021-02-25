local ecs = ...
local world = ecs.world

local qst_sys = ecs.system "quad_sphere_test_system"
local iqs = world:interface "ant.quad_sphere|iquad_sphere"
local iom = world:interface "ant.objcontroller|obj_motion"
local icamera = world:interface "ant.camera|camera"
function qst_sys:init()
    local trunk_num = 5
    local eid = iqs.create("test_quad_sphere", trunk_num, 100)
    local face = 2  --top
    local tx, ty = 1, 2
    local trunkid = face * trunk_num * trunk_num + ty * trunk_num + tx
    iqs.set_trunkid(eid, trunkid)
end

local qs_mb = world:sub{"component_register", "quad_sphere"}
function qst_sys:data_changed()
    local mq = world:singleton_entity "main_queue"
    local cameraeid = mq.camera_eid
    for _, _, eid in qs_mb:unpack() do
        icamera.focus_obj(cameraeid, eid)
    end
end