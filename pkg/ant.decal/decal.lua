local ecs = ...
local world = ecs.world
local w = world.w

local math3d = require "math3d"

local imaterial = ecs.require "ant.asset|material"

local function update_decal(decal)
    local hw, hh = decal.w * 0.5, decal.h * 0.5
    decal.frustum = {
        l = -hw, r = hw,
        b = -hh, t = hh,
        n = 0, f = 1,
        ortho = true,
    }
end

local ds = ecs.system "decal_system"

local decl_mount_mb = world:sub{"decal_mount"}

function ds:entity_init()
    for msg in decl_mount_mb:each() do
        local e, attach = msg[2], msg[3]
        --TODO: 见上一个TODO
        local attach_ro = attach.render_object
        local ro = e.render_object

        ro.vb_start, ro.vb_num = attach_ro.vb_start, attach_ro.vb_num
        ro.vb_handle = attach_ro.vb_handle

        ro.ib_start, ro.ib_num = attach_ro.ib_start, attach_ro.ib_num
        ro.ib_handle = attach_ro.ib_handle
    end
end

function ds:data_changed()
	for e in w:select "scene_changed decal:in" do
        update_decal(e.decal)
    end
end

-- rotate Z Axis -> Y Axis
local rotateYZ_MAT = math3d.ref(
    math3d.matrix(
        1, 0, 0, 0,
        0, 0, -1, 0,
        0, 1, 0, 0,
        0, 0, 0, 1)
    )

function ds:follow_scene_update()
    for e in w:select "decal:in render_object:update" do
        local ro = e.render_object
        local d = e.decal
        local mm = math3d.mul(rotateYZ_MAT, ro.worldmat)

        local viewmat = math3d.inverse(mm)
        local projmat = math3d.projmat(d.frustum)
        local viewprojmat = math3d.mul(projmat, viewmat)
        imaterial.set_property(e, "u_decal_mat", math3d.mul(viewprojmat, ro.worldmat))
    end
end