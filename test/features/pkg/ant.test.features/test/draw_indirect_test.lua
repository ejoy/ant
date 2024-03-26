--[[ local ecs   = ...
local world = ecs.world
local w     = world.w

local math3d = require "math3d"
local common = ecs.require "common"
local util  = ecs.require "util"
local PC    = util.proxy_creator()
local ig    = ecs.require "ant.group|group"
local dit_sys = common.test_system "draw_indirect"
local draw_indirect_test_group_id<const> = ig.register "draw_indirect_test"
local ie_eid

local function build_test_srts(rows, cols)
    local srts = {}

    local r = math3d.quaternion{0, 0, math.rad(90)}
    for col = -rows, rows, 2 do
        local scale, scale_step = 0.1, 0.1
        for row = -cols, cols, 2 do
            local s = math3d.vector(scale, scale, scale)
            local t = math3d.vector(row, 0 ,col)
            srts[#srts+1] = {s = s, r = r, t = t}
            scale = scale + scale_step
        end
    end
    return srts
end

function dit_sys.init_world()
    local test_srts = build_test_srts(4, 4)

    -- indirect_entity's visibility depends on its binding group
    ig.enable(draw_indirect_test_group_id, "view_visible", true)

    ie_eid = PC:create_entity{
        policy = {
            "ant.render|indirect_entity",
        },
        data = {
            indirect_entity = {
                gid         = draw_indirect_test_group_id,
                mesh        = "/pkg/ant.resources.binary/meshes/base/cube.glb/meshes/Cube_P1.meshbin",
                material    = "/pkg/ant.resources.binary/meshes/base/cube.glb/materials/Material.001.material",
                visible     = true,
                visible_masks="main_view|selectable|cast_shadow",
                render_layer= "opacity",
                srts        = test_srts
            }
        }
    }
end

local key_mb = world:sub {"keyboard"}
function dit_sys:data_changed()
    for _, key, press in key_mb:unpack() do
        if key == "G" and press == 0 then
            local test_srts = build_test_srts(8, 8)
            local ie_entity<close> = world:entity(ie_eid, "indirect_update?update indirect_entity:update")
            ie_entity.indirect_update = true
            ie_entity.indirect_entity.srts = test_srts
        end
    end

end

function dit_sys:exit()
    PC:clear()
end ]]