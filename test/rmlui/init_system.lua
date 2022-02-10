local ecs = ...

local init_sys   = ecs.system "init_system"
local iRmlUi     = ecs.import.interface "ant.rmlui|irmlui"

local function getArguments()
    return ecs.world.args.ecs.args
end

function init_sys:post_init()
    local args = getArguments()
    iRmlUi.preload_dir "/resource"
    iRmlUi.open(args[1])
end
