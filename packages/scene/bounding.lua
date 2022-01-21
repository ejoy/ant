local ecs   = ...
local world = ecs.world
local w     = world.w

local mathpkg   = import_package "ant.math"
local mc        = mathpkg.constant

local math3d = require "math3d"

local ib = ecs.interface "ibounding"
local function set_aabb_transform(e, transform)
    local s = e.scene
    if s.aabb_transform then
        s.aabb_transform = math3d.mul(math3d.matrix(transform), s.aabb_transform)
    else
        s.aabb_transform = math3d.ref(math3d.matrix(transform))
    end

    s.aabb = math3d.aabb_transform(s.aabb_transform, s.aabb)
end
function ib.set_aabb_transform(e, transform)
    w:sync("scene:in", e)
    set_aabb_transform(e, transform)
end

local bounding_sys = ecs.system "bounding_system"

local function transform_aabb(scene)
    local t = scene.aabb_transform
    if t then
        local m = math3d.ref(math3d.matrix(t))
        scene.aabb_transform = t
        scene.aabb = math3d.aabb_transform(m, scene.aabb)
    end
end

function bounding_sys:entity_init()
    for v in w:select "INIT mesh:in scene:in" do
		local mesh = v.mesh
		if mesh.bounding then
			v.scene.aabb = mesh.bounding.aabb
            transform_aabb(v.scene)
		end
	end
end