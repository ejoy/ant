local ecs = ...
local world = ecs.world
local math3d = require "math3d"

local mathpkg = import_package "ant.math"
local mc = mathpkg.constant

local ientity = world:interface "ant.render|entity"
local bb_a = ecs.action "billboard_mount"
function bb_a.init(prefab, idx, value)
    local eid = prefab[idx]
    world[eid]._rendercache.camera_eid = value
end

local bb_build = ecs.transform "build_billboard_mesh"
function bb_build.process_prefab(e)
    e.mesh = ientity.quad_mesh(e.billboard.rect)
end

local bb_sys = ecs.system "billboard_system"

function bb_sys:camera_usage()
    --TODO: need sub camera changed, not do every frame
    for _, eid in world:each "billboard" do
        local b = world[eid]
        local bb = b.billboard
        if bb.lock == "camera" then
            local rc = b._rendercache
            local ceid = rc.camera_eid

            local c_rc = world[ceid]._rendercache
            local c_wm = c_rc.worldmat

            local newviewdir = math3d.inverse(math3d.index(c_wm, 3))

            local rightdir = math3d.cross(newviewdir, mc.ZAXIS)
            local updir = math3d.cross(newviewdir, rightdir)

            local worldmat = rc.worldmat
            math3d.set_index(worldmat, rightdir, 1)
            math3d.set_index(worldmat, updir, 2)
            math3d.set_index(worldmat, newviewdir, 3)
        else
            error(("not support billboard type:%s"):format(bb.lock))
        end
    end
end