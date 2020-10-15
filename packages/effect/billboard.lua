local ecs = ...
local world = ecs.world
local math3d = require "math3d"

local mathpkg = import_package "ant.math"
local mc = mathpkg.constant

local ientity = world:interface "ant.render|entity"
local bb_a = ecs.action "billboard_mount"
function bb_a.init(prefab, idx, value)
    local eid = prefab[idx]
    world[eid]._rendercache.camera_eid = prefab[value]
end

local identity_rect<const> = {x=0, y=0, w=1, h=1}
local bc = ecs.component "billboard"
function bc:init()
    self.rect = self.rect or identity_rect
    return self
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

            local newviewdir = math3d.normalize(math3d.inverse(math3d.index(c_wm, 3)))
            local rightdir = math3d.normalize(math3d.index(c_wm, 1))
            local updir = math3d.cross(rightdir, newviewdir)
            -- matrix m = translate matrix * rotate matrix, apply rotate, and then translate
            local m = math3d.set_columns(rc.worldmat, rightdir, updir, newviewdir)
            local s = math3d.matrix{s=math3d.matrix_scale(rc.worldmat)}
            -- finally the srt order: original scale->new rotation->original translation
            rc.worldmat = math3d.mul(m, s)
        else
            error(("not support billboard type:%s"):format(bb.lock))
        end
    end
end