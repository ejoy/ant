local ecs = ...
local world = ecs.world
local w = world.w

local math3d = require "math3d"

local imaterial = ecs.import.interface "ant.asset|imaterial"
local bgfx = require "bgfx"

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
function ecs.method.decal_mount(e, attach)
    world:pub{"decal_mount", e, attach}
end

function ds:entity_init()
    for msg in decl_mount_mb:each() do
        local e, attach = msg[2], msg[3]
        
        w:sync("render_object:out", attach)
        local attach_ro = attach.render_object

        w:sync("render_object:out", e)
        local ro = e.render_object

        ro.vb = attach_ro.vb
        ro.ib = attach_ro.ib

        ro.set_transform = function ()
            bgfx.set_transform(attach_ro.worldmat)
        end
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

function ds:follow_transform_updated()
    for e in w:select "decal:in render_object:in" do
        local ro = e.render_object
        local d = e.decal
        local mm = math3d.mul(rotateYZ_MAT, ro.worldmat)

        local viewmat = math3d.inverse(mm)
        local projmat = math3d.projmat(d.frustum)
        local viewprojmat = math3d.mul(projmat, viewmat)
        imaterial.set_property_directly(ro.properties, "u_decal_mat", math3d.mul(viewprojmat, ro.worldmat))
    end
end