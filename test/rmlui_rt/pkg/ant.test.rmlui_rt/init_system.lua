local ecs = ...
local world = ecs.world
local w = world.w

local iUiRt     = ecs.require "ant.rmlui|ui_rt_system"
local init_sys   = ecs.system "init_system"
local iRmlUi     = ecs.require "ant.rmlui|rmlui_system"
local kb_mb = world:sub{"keyboard"}
local function getArguments()
    return ecs.world.args.ecs.args
end

function init_sys:init()

end

function init_sys:post_init()
    local args = getArguments()
    local window = iRmlUi.open(args[1])
    window.addEventListener("message", function (data)
        print("Message: " .. data)
    end)
end

function init_sys:data_changed()
    for _, key, press in kb_mb:unpack() do
        local rt_name = "rt1"
        local focus_path = "/pkg/ant.resources.binary/meshes/chimney-1.glb|mesh.prefab"
        local light_path= "/pkg/ant.resources/light_rt.prefab"
        local focus_srt = {
            s = {1, 1, 1},
            t = {0, 0, 0}
        }
        if key == "T" and press == 0 then
            local clear_color = 0xff0000ff
            local focus_distance = 100
            local focus_prefab_instance = iUiRt.create_new_rt(rt_name, light_path, focus_path, focus_srt, focus_distance, clear_color)
        elseif key == "J" and press == 0 then
            iUiRt.close_ui_rt(rt_name)
        elseif key == "K" and press == 0 then
            local clear_color = 0x00ff00ff
            local focus_distance
            focus_path = "/pkg/ant.resources.binary/meshes/wind-turbine-1.glb|mesh.prefab"
            local focus_prefab_instance = iUiRt.create_new_rt(rt_name, light_path, focus_path, focus_srt, focus_distance, clear_color)
        end
    end
end



function init_sys:end_frame()

end
