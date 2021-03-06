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
local math3d = require "math3d"

local num_trunk<const> = 5
local radius<const> = 10

local qs_eids = {}
function qst_sys:init()
    --front
    qs_eids[1] = iqs.create("test_quad_sphere1", num_trunk, radius)
    --iqs.set_trunkid(qs_eids[1], iqs.pack_trunkid(0, 1, 5))
    imaterial.set_property(qs_eids[1], "u_color", {0.8, 0.8, 0.8, 1})
    -- --top
    -- qs_eids[2] = iqs.create("test_quad_sphere2", num_trunk, radius)
    -- iqs.set_trunkid(qs_eids[2], iqs.pack_trunkid(2, 5, 5))
    -- imaterial.set_property(qs_eids[2], "u_color", {0, 1, 0, 1})
    -- --right
    -- qs_eids[3] = iqs.create("test_quad_sphere3", num_trunk, radius)
    -- iqs.set_trunkid(qs_eids[3], iqs.pack_trunkid(5, 1, 1))
    -- imaterial.set_property(qs_eids[3], "u_color", {0, 0, 1, 1})

    iqs.add_inscribed_cube(qs_eids[1], {1, 1, 0, 1})
    --iqs.add_solid_angle_entity(qs_eids[1], {0.9, 0.8, 0.5, 1})
end

function qst_sys:post_init()
    local mq = world:singleton_entity "main_queue"
    icc.attach(mq.camera_eid, qs_eids[1])
    local tp = {0, radius * 0.5, radius}
    tp = math3d.tovalue(math3d.mul(radius, math3d.normalize(math3d.vector(tp))))
    local targetpos = math3d.vector(tp[1], tp[2], tp[3], 1)
    icc.set_view(targetpos, {0, 2, 2, 1}, 0)

    local srt = iqs.tangent_matrix(targetpos)
    local xaxis = math3d.tovalue(math3d.add(targetpos, math3d.normalize(math3d.index(srt, 1))))
    local yaxis = math3d.tovalue(math3d.add(targetpos, math3d.normalize(math3d.index(srt, 2))))
    local zaxis = math3d.tovalue(math3d.add(targetpos, math3d.normalize(math3d.index(srt, 3))))

    local axisorigin = targetpos --math3d.muladd(math3d.normalize(targetpos), 0.1, targetpos)
    local ao = math3d.tovalue(axisorigin)
    local vertices = {
        ao[1], ao[2], ao[3],            0xff0000ff,
        xaxis[1], xaxis[2], xaxis[3],   0xff0000ff,
        ao[1], ao[2], ao[3],            0xff00ff00,
        yaxis[1], yaxis[2], yaxis[3],   0xff00ff00,
        ao[1], ao[2], ao[3],            0xffff0000,
        zaxis[1], zaxis[2], zaxis[3],   0xffff0000,
    }

    --ies.set_state(qs_eids[1], "visible",)

    local axismesh = ientity.create_mesh{"p3|c40niu", vertices}
    ientity.create_simple_render_entity(
        "axis",
        "/pkg/ant.resources/materials/line.material",
        axismesh
    )

    -- ientity.create_arrow_entity(targetpos, math3d.index(srt, 1), 0.1, {
    --     cylinder_cone_ratio = 8/3.0,
    --     cylinder_color = {1, 0, 0, 1},
    --     cone_color = {1, 0, 0, 1}
    -- })

    -- ientity.create_arrow_entity(targetpos, math3d.index(srt, 2), 0.1, {
    --     cylinder_cone_ratio = 8/3.0,
    --     cylinder_color = {0, 1, 0, 1},
    --     cone_color = {0, 1, 0, 1}
    -- })

    -- ientity.create_arrow_entity(targetpos, math3d.index(srt, 3), 0.1, {
    --     cylinder_cone_ratio = 8/3.0,
    --     cylinder_color = {0, 0, 1, 1},
    --     cone_color = {0, 0, 1, 1}
    -- })



    --icc.set_forward(cceid, 0.1)
end

local kb_mb = world:sub{"keyboard"}
function qst_sys:data_changed()
    
end

local lineeid
local cubeeids = {}
local which_qseid = 1
function qst_sys:follow_transform_updated()
    for _, key, p, status in kb_mb:unpack() do
        if key == 'SPACE' and p == 0 then
            local mq = world:singleton_entity "main_queue"
            local cameraeid = mq.camera_eid
            local center = iqs.tile_center(qs_eids[1], 16, 16)
            iqs.focus_camera(qs_eids[1], cameraeid, 20, center)
        end

        if key == 'L' and p == 0 then
            if not status.SHIFT then
                for _, eid in ipairs(qs_eids) do
                    lineeid = iqs.add_line_grid(eid)
                end
            else
                world:remove_entity(lineeid)
            end
        end

        if key == 'P' and p == 0 then
            for _, qs_eid in ipairs(qs_eids) do
                local center_tile_aabb = iqs.tile_aabb(qs_eid, 16, 16)
                local function calc_scale(base, other)
                    local _, base_extent = math3d.aabb_center_extents(base)
                    local _, other_extent = math3d.aabb_center_extents(other)

                    local b = math3d.tovalue(base_extent)
                    local bb = math3d.tovalue(other_extent)

                    local bmax = math.max(b[1], b[2], b[3])
                    local bbmax = math.max(bb[1], bb[2], bb[3])

                    return bmax / bbmax
                end

                local s

                for i=1, 32 do
                    for j=1, 32 do
                        local ceid = world:create_entity {
                            policy = {
                                "ant.render|render",
                                "ant.general|name"
                            },
                            data = {
                                transform = {},
                                material = "/pkg/ant.resources/materials/bunny.material",
                                mesh =  "/pkg/ant.resources.binary/meshes/base/cube.glb|meshes/pCube1_P1.meshbin",
                                state = 0x00000005,
                                scene_entity = true,
                                name = "qs_test_cube",
                            }
                        }

                        if s == nil then
                            s = calc_scale(center_tile_aabb, world[ceid]._bounding.aabb)
                        end
                        
                        local tx, ty = i, j
                        local m = iqs.tile_matrix(qs_eids[1], tx, ty)
                        local srt = iom.srt(ceid)
                        iom.set_srt(ceid, math3d.mul(m, srt))

                        iom.set_scale(ceid, 3)

                        cubeeids[#cubeeids+1] = ceid
                    end
                end
            end

            -- local tile_aabbs = iqs.tile_aabbs(qs_eid)
            -- for tileidx, aabb in ipairs(tile_aabbs) do
            --     local ceid = world:create_entity {
            --         policy = {
            --             "ant.render|render",
            --             "ant.general|name"
            --         },
            --         data = {
            --             transform = {},
            --             material = "/pkg/ant.resources/materials/bunny.material",
            --             mesh =  "/pkg/ant.resources.binary/meshes/base/cube.glb|meshes/pCube1_P1.meshbin",
            --             state = 0x00000005,
            --             scene_entity = true,
            --             name = "qs_test_cube",
            --         }
            --     }
            --     local cubeaabb = world[ceid]._bounding.aabb

            --     local s = calc_scale(aabb, cubeaabb)

            --     iom.set_scale(ceid, s)

            --     local tilex, tiley = tileidx % 32, tileidx // 32
            --     local center = iqs.tile_center(qs_eid, {tilex, tiley})
            --     iom.set_position(ceid, center)
            --     cubeeids[#cubeeids+1] = ceid
            -- end
        end
    end
end