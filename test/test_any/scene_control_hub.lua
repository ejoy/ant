local iupcontrols = import_package "ant.iupcontrols"
local hub = iupcontrols.common.hub
local Serialize = import_package 'ant.serialize'
local scene_control_hub = {}

-- occur when select files change
-- args:{select_res1,select_res2,...}
-- res:{package=xxx,filename = xx}
scene_control_hub.CH_OPEN_WORLD = "scene_control_open_world"

function scene_control_hub.publish_open_world(world)
    --todo
    print("todo:publish_open_world")
    -- local selected_res = fs_hierarchy_ins:get_selected_res()
    -- hub.publish(fs_hierarchy_hub.CH_SELECT_FILES, selected_res)
    if world == nil then
        return
    end
    local function save_file(file, data)
        assert(assert(io.open(file, 'w')):write(data)):close()
    end
    -- test serialize world
    local serialize_str = Serialize.save_world(world)

    hub.publish(scene_control_hub.CH_OPEN_WORLD, serialize_str)
end

-- local function test_selected(a1,a2)
--     print_a("test_selected",a1,a2)
-- end
-- hub.subscibe("fs_hierarchy_select_file",test_selected)

-- local function test_selected_m(a1,a2)
--     print_a("test_selected",a1,a2)
-- end
-- hub.subscibe_mult("fs_hierarchy_select_file",test_selected_m)

function scene_control_hub.subscibe(ins)
    local fs_hierarchy_hub = require "fs_hierarchy_hub"
    hub.subscibe(fs_hierarchy_hub.CH_OPEN_FILE,
                ins.open_scene_file,
                ins)
    local scene_hierarchy_hub = require "scene_hierarchy_hub"
    hub.subscibe(scene_hierarchy_hub.CH_FOCUS_ENTITY,
                ins.on_foucs_entity,
                ins)

end

return scene_control_hub

