local util = {}
util.__index = util

local maincamera_obj_components = {"main_camera", "position", "direction", "frustum", "viewid"}
function util.get_camera_component_names()
    return maincamera_obj_components
end

local view_entity_components = {"position", "direction", "frustum", "viewid"}
function util.get_view_entity_components()
    return view_entity_components
end

local scene_obj_components = {"position", "direction", "scale", "render"}
function util.get_sceneobj_compoent_names()
    return scene_obj_components
end

return util