local ecs = ...
local world = ecs.world
local w = world.w

local iUiRt     = ecs.import.interface "ant.rmlui|iuirt"
local init_sys   = ecs.system "init_system"
local iRmlUi     = ecs.import.interface "ant.rmlui|irmlui"
local ivs		= ecs.import.interface "ant.scene|ivisible_state"
local kb_mb = world:sub{"keyboard"}
local function getArguments()
    return ecs.world.args.ecs.args
end

function init_sys:init()

end

function init_sys:post_init()
    local args = getArguments()
    iRmlUi.add_bundle "/rml.bundle"
    iRmlUi.set_prefix "/resource"
    local window = iRmlUi.open(args[1])
    window.addEventListener("message", function (event)
        print("Message: " .. event.data)
    end)
end

local math3d        = require "math3d"
local ientity       = ecs.import.interface "ant.render|ientity"
local imaterial     = ecs.import.interface "ant.asset|imaterial"
local iom           = ecs.import.interface "ant.objcontroller|iobj_motion"
function init_sys:entity_init()
    for _, key, press in kb_mb:unpack() do
        local rt_name = "rt1"

        if key == "T" and press == 0 then
            local focus_path = "/pkg/ant.resources.binary/meshes/Duck.glb|mesh.prefab"
            local plane_path_type = "ant" -- "vaststars"/"ant"
            local focus_entity_scale = {0.1, 0.1, 0.1}
            iUiRt.create_new_rt(rt_name, focus_path, plane_path_type, focus_entity_scale)
        elseif key == "J" and press == 0 then
            iUiRt.close_ui_rt(rt_name)
        end
    end
end



function init_sys:end_frame()

end
