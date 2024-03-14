local ecs   = ...
local world = ecs.world
local w     = world.w

local math3d= require "math3d"

local common = ecs.require "common"
local util  = ecs.require "util"
local PC    = util.proxy_creator()
local iom   = ecs.require "ant.objcontroller|obj_motion"
local ig    = ecs.require "ant.group|group"
local irender = ecs.require "ant.render|render"

local hn_test_sys = common.test_system "hitch_node"

local h1, h2, h3
local HITCH_REF_GROUPID<const>    = ig.register "hitch_node_test"
local H1_GROUPID<const> = ig.register "h1_gid"

local TEST_INDIRECT<const> = false
local function create_hitch(hitch_gid, ref_gid, srt)
    PC:create_entity {
        group = hitch_gid or ig.groupid "DEFAULT",
        policy = {
            "ant.render|hitch_object",
        },
        data = {
            scene = srt,
            hitch = {
                group = ref_gid
            },
            visible = true,
            receive_shadow = true,
            cast_shadow = true,
            hitch_update = TEST_INDIRECT,
        }
    }
end

local function create_simple_test_group()
    h1 = create_hitch(H1_GROUPID, HITCH_REF_GROUPID, {t = {0, 3, 0}})
    h2 = create_hitch(nil, HITCH_REF_GROUPID, {t = {1, 2, 0}})

    local prefabname = TEST_INDIRECT and "mesh_di.prefab" or "mesh.prefab"

    --standalone sub tree
    local p1 = PC:create_instance {
        group = HITCH_REF_GROUPID,
        prefab = "/pkg/ant.resources.binary/meshes/base/cube.glb|" .. prefabname,
        on_ready = function (p)
            local root<close> = world:entity(p.tag['*'][1], "scene:update")
            iom.set_position(root, math3d.vector(0, 2, 0))
        end,
    }

    PC:create_instance {
        group = HITCH_REF_GROUPID,
        prefab = "/pkg/ant.resources.binary/meshes/base/cone.glb|" .. prefabname,
        on_ready = function (p)
            local root<close> = world:entity(p.tag['*'][1], "scene:update scene_needchange?out")
            iom.set_position(root, math3d.vector(1, 2, 3))
            root.scene.parent = p1.tag['*'][1]
            root.scene_needchange = true
        end,
    }
end

function hn_test_sys:init()
    create_simple_test_group()
    --PC:add_entity(util.create_shadow_plane(25))
end

local visible = true
local h1_enable = true
local key_mb = world:sub {"keyboard"}
function hn_test_sys:data_changed()
    for _, key, press in key_mb:unpack() do
        if key == "A" and press == 0 then
            local e <close> = world:entity(h1, "eid:in")
            w:remove(h1)
        elseif key == "B" and press == 0 then
            local e <close> = world:entity(h2, "scene:update")
            iom.set_position(e, math3d.tovalue(math3d.add(math3d.vector(0, 3, 0), e.scene.t)))
        elseif key == "X" and press == 0 then
            h1_enable = not h1_enable
            local go = irender.group_obj "view_visible"
            go:enable(H1_GROUPID, h1_enable)
            go:filter_flush()
        elseif key == "C" and press == 0 then
            h3 = create_hitch(HITCH_REF_GROUPID, {t = {0, 0, 3}})
        elseif key == "Y" and press == 0 then
            local he<close> = world:entity(h1, "visible?out")
            visible = not visible
            irender.set_visible(he, visible)
        end
    end

end

function hn_test_sys:exit()
    PC:clear()
end