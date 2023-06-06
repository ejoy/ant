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
function init_sys:data_changed()
    for _, key, press in kb_mb:unpack() do
        local rt_name = "rt1"
        local focus_path = "/pkg/ant.resources.binary/meshes/drone.prefab"
        local plane_path = "/pkg/ant.resources.binary/meshes/plane_rt.glb|mesh.prefab"
        local light_path= "/pkg/ant.resources/light_rt.prefab"
        local focus_srt = {
            s = {1, 1, 1},
            t = {0, 0, 0}
        }
        if key == "T" and press == 0 then
            local focus_prefab_instance = iUiRt.create_new_rt(rt_name, plane_path, light_path, focus_path, focus_srt)
        elseif key == "J" and press == 0 then
            iUiRt.close_ui_rt(rt_name)
        elseif key == "K" and press == 0 then
            focus_path = "/pkg/ant.resources.binary/meshes/chimney-1.glb|mesh.prefab"
            focus_path = "/pkg/ant.resources.binary/meshes/wind-turbine-1.glb|mesh.prefab"
            local focus_prefab_instance = iUiRt.create_new_rt(rt_name, plane_path, light_path, focus_path, focus_srt)
        end
    end
end



function init_sys:end_frame()

end
