local ecs   = ...
local world = ecs.world
local w     = world.w

local imgui     = require "imgui"
local math3d    = require "math3d"

local icamera   = ecs.import.interface "ant.camera|icamera"
local iom       = ecs.require "ant.objcontroller|obj_motion"


local CAMERA_SETTING_NAME<const> = "CameraSetting"

local function show_camera_setting(open)
    if open then
        if not imgui.windows.IsPopupOpen(CAMERA_SETTING_NAME) then
            imgui.windows.OpenPopup(CAMERA_SETTING_NAME)
        end
    end

    local change, opened = imgui.windows.BeginPopupModal(CAMERA_SETTING_NAME, imgui.flags.Window{"AlwaysAutoResize"})
    if change then
        local mq = w:first "main_queue camera_ref:in"
        local e<close> = w:entity(mq.camera_ref, "camera:update scene:update")

        if imgui.widget.TreeNode("Camera", imgui.flags.TreeNode { "OpenOnArrow", "SpanFullWidth", "DefaultOpen" }) then

            local frustum = e.camera.frustum
            if imgui.widget.TreeNode("Frustum", imgui.flags.TreeNode { "OpenOnArrow", "SpanFullWidth", "DefaultOpen" }) then
                
                local changed
                local uiortho = {frustum.ortho}
                if imgui.widget.Checkbox("ortho", uiortho) then
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
                    if imgui.widget.DragFloat(ui.name, t) then
                        frustum[ui.field] = t[1]
                        changed = true
                    end
                end

                if changed then
                    icamera.set_frustum(e, frustum)
                end
                imgui.widget.TreePop()
            end

            imgui.widget.TreePop()
        end

        if imgui.widget.TreeNode("Scene", imgui.flags.TreeNode { "OpenOnArrow", "SpanFullWidth", "DefaultOpen" }) then

            local uis = math3d.tovalue(e.scene.s)
            if imgui.widget.DragFloat("Scale", uis) then
                iom.set_scale(e, math3d.vector(uis[1], uis[2], uis[3]))
            end

            local uir = math3d.tovalue(math3d.quat2euler(e.scene.r))
            if imgui.widget.DragFloat("Rotation", uir) then
                uis[4] = nil
                iom.set_rotation(e, math3d.quaterion(uir))
            end

            local uit = math3d.tovalue(e.scene.t)
            if imgui.widget.DragFloat("Position", uit) then
                uit[4] = 1
                iom.set_position(e, math3d.vector(uit))
            end

            imgui.widget.TreePop()
        end
        imgui.windows.EndPopup()
    end
end

return {
    viewname = CAMERA_SETTING_NAME,
    show = show_camera_setting
}