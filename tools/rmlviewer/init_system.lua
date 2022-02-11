local ecs = ...

local init_sys   = ecs.system "init_system"
local iRmlUi     = ecs.import.interface "ant.rmlui|irmlui"

local function getArguments()
    return ecs.world.args.ecs.args
end

function init_sys:post_init()
    local args = getArguments()
    iRmlUi.preload_dir "/resource"
    local window = iRmlUi.open(args[1])
    window.addEventListener("message", function (event)
        print("Message: " .. event.data)
    end)
end
