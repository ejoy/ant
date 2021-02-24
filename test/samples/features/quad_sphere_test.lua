local ecs = ...
local world = ecs.world

local qst_sys = ecs.system "quad_sphere_test_system"
local iqs = world:interface "ant.quad_sphere|iquad_sphere"
function qst_sys:init()
    local trunk_num = 20
    local eid = iqs.create("test_quad_sphere", trunk_num, 20)
    local face = 2  --top
    local tx, ty = 4, 6
    local trunkid = face * trunk_num * trunk_num + ty * trunk_num + tx
    iqs.set_trunkid(eid, trunkid)
end

function qst_sys:data_changed()

end