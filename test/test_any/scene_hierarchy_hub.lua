local editor = import_package "ant.editor"
local hub = editor.hub
local scene_hierarchy_hub = {}

scene_hierarchy_hub.FOCUS_ENTITY = "scene_hierarchy_foucs_entity"

function scene_hierarchy_hub.subscibe(ins)
    -- local scene_control_hub = require "scene_control_hub"
    -- hub.subscibe(scene_control_hub.CH_OPEN_WORLD,
    --             ins.on_open_world,
    --             ins)
    local WatcherEvent = require "editor_watcher_event"
    hub.subscibe(WatcherEvent.SEND_HIERARCHY,
                ins.on_refresh_hierarchy,
                ins)
end

-- function scene_hierarchy_hub.watch_hierarchy()
--     local WatcherEvent = require "sys.editor_watcher_event"
--     hub.publish(WatcherEvent.WATCH_HIERARCHY
-- end

function scene_hierarchy_hub.publish_foucs_entity(eid)
    local WatcherEvent = require "editor_watcher_event"
    hub.publish(WatcherEvent.WATCH_ENTITIES, {eid})
end

return scene_hierarchy_hub

