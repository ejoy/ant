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
    for e in w:select "INIT hitch:in" do
		local _ = scene_groups[e.hitch.group]
    end
end

function vs_sys:entity_remove()
    for e in w:select "REMOVED hitch:in" do
        
    end
end