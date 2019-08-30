local ecs = ...
local luagc_system = ecs.system "luagc_system"
function luagc_system:update()
    collectgarbage "step"
end
