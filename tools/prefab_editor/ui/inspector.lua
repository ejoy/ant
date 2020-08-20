local imgui     = require "imgui"
local math3d    = require "math3d"
local uiconfig  = require "ui.config"
local uiutils   = require "ui.utils"
local hierarchy = require "hierarchy"
local m = {}
local world
local worldedit
local iom
local camera_mgr
local localSpace = {}
local viewStartY = uiconfig.WidgetStartY + uiconfig.ToolBarHeight

local baseUIData = {
    current_eid = -1,
    name = {text = "noname"},
    pos = {0,0,0, speed = 0.1},
    rot = {0,0,0, speed = 0.1},
    scale = {1,1,1, speed = 0.05},
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
    dist            = {5, speed = 0.1},
    fov_axis        = {text = "vert"},
    field_of_view   = {30, speed = 0.5},
    near_plane      = {0.1},
    far_plane       = {300},
    current_frame   = 1,
    duration        = {}
}



local function update_ui_data(eid)
    if not eid then
        return
    end
    local Pos
    local Rot
    local Scale
    if world[eid].camera then
        local frustum = icamera.get_frustum(eid)
        cameraUIData.target[1] = camera_mgr.camera_list[eid].target
        cameraUIData.dist[1] = camera_mgr.camera_list[eid].dist_to_target
        cameraUIData.near_plane[1] = frustum.n
        cameraUIData.far_plane[1] = frustum.f
        cameraUIData.field_of_view[1] = frustum.fov
        local frames = camera_mgr.get_recorder_frames(eid)
        if #frames > 0 and cameraUIData.current_frame <= #frames then
            Pos = math3d.totable(frames[cameraUIData.current_frame].position)
            Rot = math3d.totable(frames[cameraUIData.current_frame].rotation)
            Scale = {1,1,1}
        end
        for i, v in ipairs(frames) do
            cameraUIData.duration[i] = {frames[i].duration}
        end
    end
    if not Pos then
        local s, r, t = math3d.srt(iom.srt(eid))
        Pos = math3d.totable(t)
        Rot = math3d.totable(math3d.quat2euler(r))
        Scale = math3d.totable(s)
    end
    baseUIData.name.text = world[eid].name
    baseUIData.pos[1] = Pos[1]
    baseUIData.pos[2] = Pos[2]
    baseUIData.pos[3] = Pos[3]
    baseUIData.rot[1] = math.deg(Rot[1])
    baseUIData.rot[2] = math.deg(Rot[2])
    baseUIData.rot[3] = math.deg(Rot[3])
    baseUIData.scale[1] = Scale[1]
    baseUIData.scale[2] = Scale[2]
    baseUIData.scale[3] = Scale[3]
end

local gizmo

function m.set_gizmo(obj)
    gizmo = obj
end

function m.update_template_tranform(eid)
    if not eid then return end
    
    local template = hierarchy:get_template(eid)
    
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
    if world[eid].camera then
        local template_frustum = template.template.data.frustum
        local frustum = icamera.get_frustum(eid)
        template_frustum.aspect = frustum.aspect
        template_frustum.n = frustum.n
        template_frustum.f = frustum.f
        template_frustum.fov = frustum.fov
    end
end


function m.update_ui(ut)
    local eid = gizmo.target_eid
    update_ui_data(eid)
    if ut then
        m.update_template_tranform(eid)
    end
end

local function onPositionDirty(eid, pos)
    if world[eid].camera then
        local frames = camera_mgr.get_recorder_frames(eid)
        frames[cameraUIData.current_frame].position.v = pos
        camera_mgr.set_frame(eid, cameraUIData.current_frame)
    else
        local oldPos = math3d.totable(iom.get_position(eid))
        gizmo:set_position(pos)
        world:pub {"EntityEvent", "move", eid, oldPos, {pos[1], pos[2], pos[3]}}
    end
end

local function onRotateDirty(eid, rot)
    if world[eid].camera then
        local frames = camera_mgr.get_recorder_frames(eid)
        frames[cameraUIData.current_frame].rotation.v = rot
        camera_mgr.set_frame(eid, cameraUIData.current_frame)
    else
        local oldRot = math3d.totable(iom.get_rotation(eid))
        gizmo:set_rotation(rot)
        world:pub {"EntityEvent", "rotate", eid, oldRot, {rot[1], rot[2], rot[3]}}
    end
end

local function onScaleDirty(eid, scale)
    if world[eid].camera then
        
    else
        local oldScale = math3d.totable(iom.get_scale(eid))
        gizmo:set_scale(scale)
        world:pub {"EntityEvent", "scale", eid, oldScale, {scale[1], scale[2], scale[3]}}
    end
end

local function setCurrentFrame(eid, idx, force)
    if cameraUIData.current_frame == idx and not force then return end
    cameraUIData.current_frame = idx
    update_ui_data(eid)
    camera_mgr.set_frame(eid, idx)
end

function m.show(rhwi)
    local sw, sh = rhwi.screen_size()
    imgui.windows.SetNextWindowPos(sw - uiconfig.PropertyWidgetWidth, viewStartY, 'F')
    imgui.windows.SetNextWindowSize(uiconfig.PropertyWidgetWidth, sh - uiconfig.ResourceBrowserHeight - viewStartY, 'F')
    
    local current_eid = gizmo.target_eid
    for _ in uiutils.imgui_windows("Inspector", imgui.flags.Window { "NoCollapse", "NoClosed" }) do
        if current_eid then
            if baseUIData.current_eid ~= current_eid then
                baseUIData.current_eid = current_eid
                if world[current_eid].camera then
                    setCurrentFrame(current_eid, 1, true)
                end
                update_ui_data(current_eid)
            end
            local template = hierarchy:get_template(current_eid)
            if template and template.filename then
                imgui.widget.Text("Prefab :")
                imgui.cursor.SameLine()
                imgui.widget.Text(template.filename)
            end

            if imgui.widget.InputText("Name", baseUIData.name) then
                local name = tostring(baseUIData.name.text)
                world[current_eid].name = name
                world:pub {"EntityEvent", "name", current_eid, name}
            end

            if imgui.widget.TreeNode("Transform", imgui.flags.TreeNode { "DefaultOpen" }) then
                if imgui.widget.DragFloat("Position", baseUIData.pos) then
                    onPositionDirty(current_eid, baseUIData.pos)
                end
                if imgui.widget.DragFloat("Rotate", baseUIData.rot) then
                    onRotateDirty(current_eid, baseUIData.rot)
                end
                if imgui.widget.DragFloat("Scale", baseUIData.scale) then
                    onScaleDirty(current_eid, baseUIData.scale)
                end
                imgui.widget.TreePop()
            end
            -- if imgui.widget.TreeNode("Material", imgui.flags.TreeNode { "DefaultOpen" }) then
            --     if imgui.widget.InputText("mtlFile", baseUIData.material) then
            --         world[current_eid].material = tostring(baseUIData.material.text)
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
            if world[current_eid] and world[current_eid].camera then
                if imgui.widget.TreeNode("Camera", imgui.flags.TreeNode { "DefaultOpen" }) then
                    local what
                    local value
                    if imgui.widget.InputInt("Target", cameraUIData.target) then
                        if hierarchy:get_node(cameraUIData.target[1]) then
                            what = "target"
                            value = cameraUIData.target[1]
                        end
                    end
                    if cameraUIData.target ~= -1 then
                        if imgui.widget.DragFloat("Dist", cameraUIData.dist) then
                            what = "dist"
                            value = cameraUIData.dist[1]
                        end
                    end
                    if imgui.widget.DragFloat("FOV", cameraUIData.field_of_view) then
                        what = "fov"
                        value = cameraUIData.field_of_view[1]
                    end
                    if imgui.widget.DragFloat("Near", cameraUIData.near_plane) then
                        what = "near"
                        value = cameraUIData.near_plane[1]
                    end
                    if imgui.widget.DragFloat("Far", cameraUIData.far_plane) then
                        what = "far"
                        value = cameraUIData.far_plane[1]
                    end
                    imgui.cursor.Separator()
                    if imgui.widget.Button("AddFrame") then
                        local new_idx = cameraUIData.current_frame + 1
                        camera_mgr.add_recorder_frame(current_eid, new_idx)
                        setCurrentFrame(current_eid, new_idx, true)
                        local frames = camera_mgr.get_recorder_frames(current_eid)
                        cameraUIData.duration[new_idx] = {frames[new_idx].duration}
                    end
                    local frames = camera_mgr.get_recorder_frames(current_eid)
                    if #frames > 1 then
                        imgui.cursor.SameLine()
                        if imgui.widget.Button("DeleteFrame") then
                            camera_mgr.delete_recorder_frame(current_eid, cameraUIData.current_frame)
                            table.remove(cameraUIData.duration, cameraUIData.current_frame)
                            if cameraUIData.current_frame > #frames then
                                setCurrentFrame(current_eid, #frames)
                            end
                        end
                        imgui.cursor.SameLine()
                        if imgui.widget.Button("Play") then
                            camera_mgr.play_recorder(current_eid)
                        end
                    end
                    if #frames > 0 then
                        imgui.cursor.Columns(2, "FrameColumns", false)
                        imgui.widget.Text("FrameIndex")
                        imgui.cursor.NextColumn()
                        imgui.widget.Text("Duration")
                        imgui.cursor.NextColumn()
                        imgui.cursor.Separator()
                        for i, v in ipairs(frames) do
                            if imgui.widget.Selectable(i, cameraUIData.current_frame == i) then
                                setCurrentFrame(current_eid, i)
                            end
                            imgui.cursor.NextColumn()
                            if imgui.widget.DragFloat("##"..i, cameraUIData.duration[i]) then
                                frames[i].duration = cameraUIData.duration[i][1]
                            end
                            imgui.cursor.NextColumn()
                        end
                        imgui.cursor.Columns(1)
                    end

                    if what then
                        world:pub {"CameraEdit", what, current_eid, value}
                    end
                    imgui.widget.TreePop()
                end
            end
        end
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