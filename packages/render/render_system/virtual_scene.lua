local ecs   = ...
local world = ecs.world
local w     = world.w

local vs_sys = ecs.system "virtual_scene_system"
local scene_groups = setmetatable({}, {__index=function(t, k)
    local tt = {}
    t[k] = tt
    return tt
end})

function vs_sys:entity_init()
    for e in w:select "INIT virtual_scene:in" do
		local _ = scene_groups[e.virtual_scene.group]
    end
end

function vs_sys:entity_remove()
    for e in w:select "REMOVED virtual_scene:in" do
        
    end
end