local ecs = ...
local world = ecs.world

local qst_sys = ecs.system "quad_sphere_test_system"
local iqs = world:interface "ant.quad_sphere|iquad_sphere"
local iom = world:interface "ant.objcontroller|obj_motion"
local imaterial = world:interface "ant.asset|imaterial"
local icamera = world:interface "ant.camera|camera"
local ientity = world:interface "ant.render|entity"
local ies = world:interface "ant.scene|ientity_state"
local icc = world:interface "ant.quad_sphere|icamera_controller"
local iqsd = world:interface "ant.quad_sphere|iquad_sphere_debug"
local math3d = require "math3d"

local num_trunk<const> = 5
local radius<const> = 10

local qseid
function qst_sys:init()
    qseid = iqs.create("test_quad_sphere1", num_trunk, radius,{
        {
            index=1,
            name="background",
            region={0.0, 0.0, 0.5, 0.5},
        },
        {
            index=2,
            name="background",
            region={0.5, 0.0, 0.5, 0.5},
        },
        {
            index=3,
            name="background",
            region={0.0, 0.5, 0.5, 0.5},
        },
    })
    iqsd.add_inscribed_cube(qseid, {1, 1, 0, 1})
end

function qst_sys:post_init()
    local mq = world:singleton_entity "main_queue"
    icc.attach(mq.camera_eid, qseid)
    local tp = {0, radius * 0.5, radius}
    tp = math3d.tovalue(math3d.mul(radius, math3d.normalize(math3d.vector(tp))))
    local targetpos = math3d.vector(tp[1], tp[2], tp[3], 1)
    icc.set_view(targetpos, {0, 2, 2, 1}, 0)
end

local kb_mb = world:sub{"keyboard"}
function qst_sys:data_changed()
    
end

local lineeids = {}
local solid_angle_eids = {}
local axiseids = {}
local function remove_eids(eids)
    for _, eid in ipairs(eids) do
        world:remove_entity(eid)
    end
end
function qst_sys:follow_transform_updated()
    for _, key, p, status in kb_mb:unpack() do
        if key == 'L' and p == 0 then
            if status.SHIFT then
                remove_eids(lineeids)
            else
                for _, eid in ipairs(world[qseid]._quad_sphere.trunk_entity_pool) do
                    lineeids[#lineeids+1] = iqs.add_line_grid(eid)
                end
            end
        end

        if key == 'c' and p == 0 then
            if status.SHIFT then
                remove_eids(solid_angle_eids)
            else
                for _, teid in ipairs(world[qseid]._quad_sphere.trunk_entity_pool) do
                    solid_angle_eids[#solid_angle_eids+1] = iqs.add_solid_angle_entity(teid, {0.9, 0.8, 0.5, 1})
                end
            end
        end

        if key == 'k' and p == 0 then
            if status.SHIFT then
                remove_eids(axiseids)
            else
                for _, teid in ipairs(world[qseid]._quad_sphere.trunk_entity_pool) do
                    axiseids[#axiseids+1] = iqs.add_axis(teid, {0.9, 0.8, 0.5, 1})
                end
            end
        end
    end
end