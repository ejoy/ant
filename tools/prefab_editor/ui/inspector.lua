local imgui     = require "imgui"
local math3d    = require "math3d"
local uiconfig  = require "ui.config"
local uiutils   = require "ui.utils"
local prefab_view = require "prefab_view"
local prefab_view = require "prefab_view"
local m = {}
local world
local worldedit
local iom
local camera_mgr
local localSpace = {}
local viewStartY = uiconfig.WidgetStartY + uiconfig.ToolBarHeight

local baseUIData = {
    eid = {0, flags = imgui.flags.InputText{ "ReadOnly" }},
    name = {text = "noname"},
    pos = {0,0,0},
    rot = {0,0,0},
    scale = {1,1,1},
    color = {}
}

local entityUIData = {
    state       = {0},
    material    = {text = "nomaterial"},
}

local lightUIData = {

}

local cameraUIData = {
    target          = {-1},
    dist            = {5},
    fov_axis        = {text = "vert"},
    field_of_view   = {30},
    near_plane      = {0.1},
    far_plane       = {300}
}



local function update_ui_data(eid)
    if not eid then
        return
    end
    local s, r, t = math3d.srt(iom.srt(eid))
    local Pos = math3d.totable(t)
    baseUIData.pos[1] = Pos[1]
    baseUIData.pos[2] = Pos[2]
    baseUIData.pos[3] = Pos[3]

    local Rot = math3d.totable(math3d.quat2euler(r))
    baseUIData.rot[1] = math.deg(Rot[1])
    baseUIData.rot[2] = math.deg(Rot[2])
    baseUIData.rot[3] = math.deg(Rot[3])

    local Scale = math3d.totable(s)
    baseUIData.scale[1] = Scale[1]
    baseUIData.scale[2] = Scale[2]
    baseUIData.scale[3] = Scale[3]
    --
    if world[eid]["tag_camera"] then
        local frustum = icamera.get_frustum(eid)
        cameraUIData.target[1] = camera_mgr[eid].target
        cameraUIData.dist[1] = camera_mgr[eid].dist_to_target
        cameraUIData.near_plane[1] = frustum.n
        cameraUIData.far_plane[1] = frustum.f
        cameraUIData.field_of_view[1] = frustum.fov
    end
end

local function on_select(eid)
    baseUIData.eid[1] = eid
    baseUIData.name.text = world[eid].name
    update_ui_data(eid)
    entityUIData.state[1] = world[eid]._rendercache.state
    
    -- baseUIData.material.text = world[eid].material.filename
    -- baseUIData.mesh.text = world[eid].mesh.filename
end

local gizmo

function m.set_gizmo(obj)
    gizmo = obj
end

function m.update_template_tranform(eid)
    if not eid then return end
    
    local template = prefab_view:get_template(eid)
    
    if not template or not template.template then return end

    local s, r, t = math3d.srt(iom.srt(eid))
    local ts, tr, tt = math3d.totable(s), math3d.totable(r), math3d.totable(t)
    local srt_table = {
        r = {tr[1], tr[2], tr[3], tr[4]},
        s = {ts[1], ts[2], ts[3]},
        t = {tt[1], tt[2], tt[3]}
    }
    template.template.data.transform = srt_table
    --worldedit:prefab_set(template.prefab, "/" .. tostring(template.index) .."/data/transform", srt_table)
end


function m.update_ui(ut)
    local eid = gizmo.target_eid
    update_ui_data(eid)
    if ut then
        m.update_template_tranform(eid)
    end
end

function m.show(rhwi)
    local sw, sh = rhwi.screen_size()
    imgui.windows.SetNextWindowPos(sw - uiconfig.PropertyWidgetWidth, viewStartY, 'F')
    imgui.windows.SetNextWindowSize(uiconfig.PropertyWidgetWidth, sh - uiconfig.ResourceBrowserHeight - viewStartY, 'F')
    
    local oldPos = nil
    local oldRot = nil
    local oldScale = nil
    
    for _ in uiutils.imgui_windows("Inspector", imgui.flags.Window { "NoCollapse", "NoScrollbar", "NoClosed" }) do
        if gizmo.target_eid then
            if baseUIData.eid[1] ~= gizmo.target_eid then
                on_select(gizmo.target_eid)
            end
            imgui.widget.Text("EID :")
            imgui.cursor.SameLine()
            imgui.widget.Text(baseUIData.eid[1])
            local template = prefab_view:get_template(baseUIData.eid[1])
            if template and template.filename then
                imgui.widget.Text("Prefab :")
                imgui.cursor.SameLine()
                imgui.widget.Text(template.filename)
            end

            if imgui.widget.InputText("Name", baseUIData.name) then
                local name = tostring(baseUIData.name.text)
                world[baseUIData.eid[1]].name = name
                world:pub {"EntityEvent", "name", baseUIData.eid[1], name}
            end

            if imgui.widget.TreeNode("Transform", imgui.flags.TreeNode { "DefaultOpen" }) then
                if imgui.widget.InputFloat("Position", baseUIData.pos) then
                    oldPos = math3d.totable(iom.get_position(baseUIData.eid[1]))
                    gizmo:set_position(baseUIData.pos)
                end
                if imgui.widget.InputFloat("Rotate", baseUIData.rot) then
                    oldRot = math3d.totable(iom.get_rotation(baseUIData.eid[1]))
                    gizmo:set_rotation(baseUIData.rot)
                end
                if imgui.widget.InputFloat("Scale", baseUIData.scale) then
                    oldScale = math3d.totable(iom.get_scale(baseUIData.eid[1]))
                    gizmo:set_scale(baseUIData.scale)
                end
                imgui.widget.TreePop()
            end
            -- if imgui.widget.TreeNode("Material", imgui.flags.TreeNode { "DefaultOpen" }) then
            --     if imgui.widget.InputText("mtlFile", baseUIData.material) then
            --         world[baseUIData.eid[1]].material = tostring(baseUIData.material.text)
            --     end
            --     if imgui.widget.BeginDragDropTarget() then
            --         local payload = imgui.widget.AcceptDragDropPayload("DragFile")
            --         if payload then
            --             print(payload)
            --         end
            --         imgui.widget.EndDragDropTarget()
            --     end
            --     imgui.widget.TreePop()
            -- end
            
            -- if imgui.widget.InputText("Name", baseUIData.mesh) then
            --     world[baseUIData.eid[1]].mesh = tostring(baseUIData.mesh.text)
            -- end
            if world[gizmo.target_eid]["tag_camera"] then
                if imgui.widget.TreeNode("Camera", imgui.flags.TreeNode { "DefaultOpen" }) then
                    local what
                    local value
                    if imgui.widget.InputInt("Target", cameraUIData.target) then
                        what = "target"
                        value = cameraUIData.target[1]
                    end
                    if cameraUIData.target ~= -1 then
                        if imgui.widget.InputInt("Dist", cameraUIData.dist) then
                            what = "dist"
                            value = cameraUIData.dist[1]
                        end
                    end
                    if imgui.widget.InputFloat("FOV", cameraUIData.field_of_view) then
                        what = "fov"
                        value = cameraUIData.field_of_view[1]
                    end
                    if imgui.widget.InputFloat("Near", cameraUIData.near_plane) then
                        what = "near"
                        value = cameraUIData.near_plane[1]
                    end
                    if imgui.widget.InputFloat("Far", cameraUIData.far_plane) then
                        what = "far"
                        value = cameraUIData.far_plane[1]
                    end
                    if what then
                        -- icamera.set_frustum(gizmo.target_eid, {
                        --     fov = cameraUIData.field_of_view[1]
                        --     n = cameraUIData.near_plane[1],
                        --     f = cameraUIData.far_plane[1]
                        -- })
                        world:pub {"CameraEdit", what, gizmo.target_eid, value}
                    end
                    imgui.widget.TreePop()
                end
            end
        end
    end

    if oldPos then
        world:pub {"EntityEvent", "move", gizmo.target_eid, oldPos, {baseUIData.pos[1], baseUIData.pos[2], baseUIData.pos[3]}}
        oldPos = nil
    elseif oldRot then
        world:pub {"EntityEvent", "rotate", gizmo.target_eid, oldRot, {baseUIData.rot[1], baseUIData.rot[2], baseUIData.rot[3]}}
        oldRot = nil
    elseif oldScale then
        world:pub {"EntityEvent", "scale", gizmo.target_eid, oldScale, {baseUIData.scale[1], baseUIData.scale[2], baseUIData.scale[3]}}
        oldScale = nil
    end
end

return function(w)
    world = w
    iom = world:interface "ant.objcontroller|obj_motion"
    icamera = world:interface "ant.camera|camera"
    worldedit = import_package "ant.editor".worldedit(world)
    camera_mgr = require "camera_manager"(world)
    return m
end