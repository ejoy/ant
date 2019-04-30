local iupcontrols = import_package "ant.iupcontrols"
local hub = iupcontrols.common.hub

local entity_property = {}

-- entity_property.CH_FOCUS_ENTITY = "scene_hierarchy_foucs_entity"

function entity_property.subscibe(ins)
    local scene_hierarchy_hub = require "scene_hierarchy_hub"
    hub.subscibe(scene_hierarchy_hub.CH_FOCUS_ENTITY,
                ins.on_focus_entity,
                ins)
end

-- function entity_property.publish_foucs_entity(eid)
--     -- hub.publish(entity_property.CH_FOCUS_ENTITY, eid)
-- end

return entity_property

