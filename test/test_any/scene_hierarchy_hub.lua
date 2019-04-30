local iupcontrols = import_package "ant.iupcontrols"
local hub = iupcontrols.common.hub

local scene_hierarchy_hub = {}

scene_hierarchy_hub.CH_FOCUS_ENTITY = "scene_hierarchy_foucs_entity"

function scene_hierarchy_hub.subscibe(ins)
    local scene_control_hub = require "scene_control_hub"
    hub.subscibe(scene_control_hub.CH_OPEN_WORLD,
                ins.on_open_world,
                ins)
end

function scene_hierarchy_hub.publish_foucs_entity(eid)
    hub.publish(scene_hierarchy_hub.CH_FOCUS_ENTITY, eid)
end

return scene_hierarchy_hub

