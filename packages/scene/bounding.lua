local ecs   = ...
local world = ecs.world
local w     = world.w

local bounding_sys = ecs.system "bounding_system"

local math3d = require "math3d"

local function init_scene_aabb(scene, bounding)
    if bounding then
        scene.aabb = math3d.mark(bounding.aabb)
        scene.scene_aabb = math3d.mark(math3d.aabb())
    end
end

function bounding_sys:entity_init()
    for v in w:select "INIT mesh:in scene:in" do
        init_scene_aabb(v.scene, v.mesh.bounding)
    end

    for v in w:select "INIT simplemesh:in scene:in" do
        init_scene_aabb(v.scene, v.simplemesh.bounding)
    end

    --TODO: should move to render package
    for v in w:select "INIT scene:in render_object:in" do
        v.render_object.aabb = v.scene.scene_aabb
    end
end