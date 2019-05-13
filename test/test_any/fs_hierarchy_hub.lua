local editor = import_package "ant.editor"
local hub = editor.hub

local fs_hierarchy_hub = {}

-- occur when select files change
-- args:{select_res1,select_res2,...}
-- res:{package=xxx,filename = xx}
fs_hierarchy_hub.CH_SELECT_FILES = "fs_hierarchy_select_file"
fs_hierarchy_hub.CH_OPEN_FILE = "fs_hierarchy_open_file"

function fs_hierarchy_hub.publish_selected(fs_hierarchy_ins)
    local selected_res = fs_hierarchy_ins:get_selected_res()
    hub.publish(fs_hierarchy_hub.CH_SELECT_FILES, selected_res)
end

function fs_hierarchy_hub.publish_open(fs_hierarchy_ins)
    local selected_res = fs_hierarchy_ins:get_selected_res()
    hub.publish(fs_hierarchy_hub.CH_OPEN_FILE, selected_res[0])
end

-- local function test_selected(a1,a2)
--     print_a("test_selected",a1,a2)
-- end
-- hub.subscibe("fs_hierarchy_select_file",test_selected)

-- local function test_selected_m(a1,a2)
--     print_a("test_selected",a1,a2)
-- end
-- hub.subscibe_mult("fs_hierarchy_select_file",test_selected_m)

return fs_hierarchy_hub

