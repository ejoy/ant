local editor = import_package "ant.editor"
local hub = editor.hub

local entity_property = {}

-- entity_property.FOCUS_ENTITY = "scene_hierarchy_foucs_entity"

function entity_property.subscibe(ins)
    -- local scene_hierarchy_hub = require "scene_hierarchy_hub"
    -- hub.subscibe(scene_hierarchy_hub.FOCUS_ENTITY,
    --             ins.on_focus_entity,
    --             ins)
    local WatcherEvent = require "editor_watcher_event"
    hub.subscibe(WatcherEvent.SEND_ENTITIES,ins.on_refresh_entities,ins)
    hub.subscibe(WatcherEvent.RESPONSE_WORLD_INFO,
                ins.on_response_world_info,
                ins)
end

function entity_property.publish_modify_component(eid,id,key,value)
    local WatcherEvent = require "editor_watcher_event"
    hub.publish(WatcherEvent.MODIFY_COMPONENT,eid,id,key,value)
end

-- function entity_property.publish_foucs_entity(eid)
--     -- hub.publish(entity_property.FOCUS_ENTITY, eid)
-- end

return entity_property

