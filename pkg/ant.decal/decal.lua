local ecs = ...
local world = ecs.world
local w = world.w

local math3d = require "math3d"

local imaterial = ecs.require "ant.render|material"
local icamera   = ecs.require "ant.camera|camera"
local MESH      = world:clibs "render.mesh"

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
function ds:entity_init()
    for e in w:select "INIT decal:in scene:in" do
        --We assume parent is the attach object
        local ae = world:entity(e.scene.parent, "render_object:in")
        local aero = ae.render_object

        for _, n in ipairs{"vb0", "vb1", "ib"} do
            local start, num, handle = MESH.fetch(aero.mesh_idx, n)
            if handle ~= 0xffff then
                local ro = e.render_object
                MESH.set(ro.mesh_idx, n, start, num, handle)
            end
        end
    end
end

function ds:data_changed()
	for e in w:select "scene_changed decal:in" do
        update_decal(e.decal)
    end
end

-- rotate Z Axis -> Y Axis
local rotateYZ_MAT = math3d.constant("mat",
    math3d.matrix(
        1, 0, 0, 0,
        0, 0,-1, 0,
        0, 1, 0, 0,
        0, 0, 0, 1)
)

function ds:follow_scene_update()
    for e in w:select "decal:in render_object:update" do
        local ro = e.render_object
        local d = e.decal
        local mm = math3d.mul(rotateYZ_MAT, ro.worldmat)
        icamera.update_camera_matrices(e.camera, math3d.inverse_fast(mm), d.frustum)
        imaterial.set_property(e, "u_decal_mat", math3d.mul(e.camera.viewprojmat, ro.worldmat))
    end
end