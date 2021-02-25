local ecs = ...
local world = ecs.world

local qst_sys = ecs.system "quad_sphere_test_system"
local iqs = world:interface "ant.quad_sphere|iquad_sphere"
local iom = world:interface "ant.objcontroller|obj_motion"
local icamera = world:interface "ant.camera|camera"

local qs_eid
function qst_sys:init()
    local trunk_num = 5
    qs_eid = iqs.create("test_quad_sphere", trunk_num, 100)
    local face = 2  --top
    local tx, ty = 1, 2
    local trunkid = face * trunk_num * trunk_num + ty * trunk_num + tx
    iqs.set_trunkid(qs_eid, trunkid)
end

local qs_mb = world:sub{"component_register", "quad_sphere"}
local kb_mb = world:sub{"keyboard", 'SPACE'}
function qst_sys:data_changed()
    
end

function qst_sys:follow_transform_updated()
    local mq = world:singleton_entity "main_queue"
    local cameraeid = mq.camera_eid
    for _, _, p in kb_mb:unpack() do
        if p == 0 then 
            icamera.focus_obj(cameraeid, qs_eid)
        end
    end
end