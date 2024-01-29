local ecs   = ...
local world = ecs.world
local w     = world.w

local ImGui     = import_package "ant.imgui"
local math3d    = require "math3d"

local icamera   = ecs.require "ant.camera|camera"
local iom       = ecs.require "ant.objcontroller|obj_motion"


local CAMERA_SETTING_NAME<const> = "CameraSetting"

local function show_camera_setting(open)
    if open then
        if not ImGui.IsPopupOpen(CAMERA_SETTING_NAME) then
            ImGui.OpenPopup(CAMERA_SETTING_NAME)
        end
    end

    local change = ImGui.BeginPopupModal(CAMERA_SETTING_NAME, nil, ImGui.Flags.Window{"AlwaysAutoResize"})
    if change then
        local mq = w:first "main_queue camera_ref:in"
        local e<close> = world:entity(mq.camera_ref, "camera:update scene:update")

        if ImGui.TreeNode("Camera", ImGui.Flags.TreeNode { "OpenOnArrow", "SpanFullWidth", "DefaultOpen" }) then

            local frustum = e.camera.frustum
            if ImGui.TreeNode("Frustum", ImGui.Flags.TreeNode { "OpenOnArrow", "SpanFullWidth", "DefaultOpen" }) then
                
                local changed
                local uiortho = {frustum.ortho}
                if ImGui.Checkbox("ortho", uiortho) then
                    frustum.ortho = uiortho[1]
                    changed = true

                    if frustum.ortho then
                        frustum.fov = nil
                        frustum.aspect = nil
                    end
                end

                local uifrustum = {
                    {field = "n", name = "Near"},
                    {field = "f", name = "Far"},
                }

                if frustum.ortho then
                    uifrustum[#uifrustum+1] = {field = "l", name = "Left", defaultvalue = -100}
                    uifrustum[#uifrustum+1] = {field = "r", name = "Right", defaultvalue = 100}
                    uifrustum[#uifrustum+1] = {field = "t", name = "Top", defaultvalue = 100}
                    uifrustum[#uifrustum+1] = {field = "b", name = "Bottom", defaultvalue = -100}
                else
                    uifrustum[#uifrustum+1] = {field = "aspect", name = "Aspect", defaultvalue = 8/6}
                    uifrustum[#uifrustum+1] = {field = "fov", name = "Fov", defaultvalue = 60}
                end

                for _, ui in ipairs(uifrustum) do
                    local t = {frustum[ui.field] or ui.defaultvalue}
                    if ImGui.DragFloat(ui.name, t) then
                        frustum[ui.field] = t[1]
                        changed = true
                    end
                end

                if changed then
                    icamera.set_frustum(e, frustum)
                end
                ImGui.TreePop()
            end

            ImGui.TreePop()
        end

        if ImGui.TreeNode("Scene", ImGui.Flags.TreeNode { "OpenOnArrow", "SpanFullWidth", "DefaultOpen" }) then

            local uis = math3d.tovalue(e.scene.s)
            if ImGui.DragFloat("Scale", uis) then
                iom.set_scale(e, math3d.vector(uis[1], uis[2], uis[3]))
            end

            local uir = math3d.tovalue(math3d.quat2euler(e.scene.r))
            if ImGui.DragFloat("Rotation", uir) then
                uis[4] = nil
                iom.set_rotation(e, math3d.quaterion(uir))
            end

            local uit = math3d.tovalue(e.scene.t)
            if ImGui.DragFloat("Position", uit) then
                uit[4] = 1
                iom.set_position(e, math3d.vector(uit))
            end

            ImGui.TreePop()
        end
        ImGui.EndPopup()
    end
end

return {
    viewname = CAMERA_SETTING_NAME,
    show = show_camera_setting
}