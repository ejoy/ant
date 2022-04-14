local ecs   = ...
local world = ecs.world
local w     = world.w

local bounding_sys = ecs.system "bounding_system"

function bounding_sys:entity_init()
    for v in w:select "INIT mesh:in scene:in" do
		local m = v.mesh
		if m.bounding then
            v.scene.aabb = m.bounding.aabb
        end
    end

    for v in w:select "INIT simplemesh:in scene:in" do
        local sm = v.simplemesh
		if sm.bounding then
            v.scene.aabb = sm.bounding.aabb
        end
    end
end