local ecs = ...
local world = ecs.world
local w = world.w

local init_sys   = ecs.system "init_system"
local iRmlUi     = ecs.require "ant.rmlui|rmlui_system"

local function getArguments()
    return ecs.world.args.ecs.args
end
function init_sys:post_init()
    local args = getArguments()
    iRmlUi.add_bundle "/rml.bundle"
    iRmlUi.set_prefix "/resource"
    iRmlUi.font_dir "/pkg/ant.resources.binary/ui/test/assets/font/"
    local window = iRmlUi.open(args[1])
    window.addEventListener("message", function (event)
        print("Message: " .. event.data)
    end)
end


