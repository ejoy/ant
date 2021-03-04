local ecs = ...
local world = ecs.world

local qst_sys = ecs.system "quad_sphere_test_system"
local iqs = world:interface "ant.quad_sphere|iquad_sphere"
local iom = world:interface "ant.objcontroller|obj_motion"
local imaterial = world:interface "ant.asset|imaterial"
local icc = world:interface "ant.quad_sphere|icamera_controller"

local math3d = require "math3d"

local num_trunk<const> = 5
local radius<const> = 10

local qs_eids = {}
function qst_sys:init()
    --front
    qs_eids[1] = iqs.create("test_quad_sphere1", num_trunk, radius)
    --iqs.set_trunkid(qs_eids[1], iqs.pack_trunkid(0, 1, 5))
    imaterial.set_property(qs_eids[1], "u_color", {1, 0, 0, 1})
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
    local cceid = icc.create(mq.camera_eid, qs_eids[1])
    icc.set_view(cceid, {0, 0, radius}, {0, 5, -10}, 0.1)
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