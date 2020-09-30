local imgui     = require "imgui"
local math3d    = require "math3d"
local uiconfig  = require "widget.config"
local uiutils   = require "widget.utils"
local hierarchy = require "hierarchy"
local light_gizmo
local gizmo
local material_panel
local m = {}
local world
local worldedit
local iom
local camera_mgr

local base_ui_data = {
    current_eid = -1,
    name = {text = "noname"},
    pos = {0,0,0, speed = 0.1},
    rot = {0,0,0, speed = 0.1},
    scale = {1,1,1, speed = 0.05}
}

local light_ui_data = {
    color = {1,1,1,1},
    intensity = {2, speed = 0.1},
    range = {1, speed = 0.1},
    radian = {0.5, speed = 0.1}
}

local camera_ui_data = {
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
    if not eid then return end
    local pos
    local rot
    local scale
    if world[eid].camera then
        local frustum = icamera.get_frustum(eid)
        camera_ui_data.target[1] = camera_mgr.camera_list[eid].target
        camera_ui_data.dist[1] = camera_mgr.camera_list[eid].dist_to_target
        camera_ui_data.near_plane[1] = frustum.n
        camera_ui_data.far_plane[1] = frustum.f
        camera_ui_data.field_of_view[1] = frustum.fov
        local frames = camera_mgr.get_recorder_frames(eid)
        if #frames > 0 and camera_ui_data.current_frame <= #frames then
            pos = math3d.totable(frames[camera_ui_data.current_frame].position)
            rot = math3d.totable(frames[camera_ui_data.current_frame].rotation)
            scale = {1,1,1}
        end
        for i, v in ipairs(frames) do
            camera_ui_data.duration[i] = {frames[i].duration}
        end
    end
    if world[eid].light_type then
        local value = math3d.totable(ilight.intensity(eid))
        light_ui_data.intensity[1] = value[1]
        light_ui_data.range[1] = ilight.range(eid)
        light_ui_data.radian[1] = ilight.radian(eid)
        local color = math3d.totable(ilight.color(eid))
        light_ui_data.color[1] = color[1]
        light_ui_data.color[2] = color[2]
        light_ui_data.color[3] = color[3]
        light_ui_data.color[4] = color[4]
    end
    if not pos then
        local s, r, t = math3d.srt(iom.srt(eid))
        pos = math3d.totable(t)
        rot = math3d.totable(math3d.quat2euler(r))
        scale = math3d.totable(s)
    end
    base_ui_data.name.text = world[eid].name
    base_ui_data.pos[1] = pos[1]
    base_ui_data.pos[2] = pos[2]
    base_ui_data.pos[3] = pos[3]
    base_ui_data.rot[1] = math.deg(rot[1])
    base_ui_data.rot[2] = math.deg(rot[2])
    base_ui_data.rot[3] = math.deg(rot[3])
    base_ui_data.scale[1] = scale[1]
    base_ui_data.scale[2] = scale[2]
    base_ui_data.scale[3] = scale[3]
    
    material_panel.update_ui_data(eid)
end

function m.update_template_tranform(eid)
    if not eid then return end
    
    local template = hierarchy:get_template(eid)
    
    if not template or not template.template then return end

    local s, r, t = math3d.srt(iom.srt(eid))
    local ts, tr, tt = math3d.totable(s), math3d.totable(r), math3d.totable(t)
    template.template.data.transform = {
        r = {tr[1], tr[2], tr[3], tr[4]},
        s = {ts[1], ts[2], ts[3]},
        t = {tt[1], tt[2], tt[3]}
    }
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

local function on_position_dirty(eid, pos)
    local oldPos = math3d.totable(iom.get_position(eid))
    local tp = {pos[1], pos[2], pos[3]}
    gizmo:set_position(pos)
    world:pub {"EntityEvent", "move", eid, oldPos, tp}
    if world[eid].camera then
        local frames = camera_mgr.get_recorder_frames(eid)
        frames[camera_ui_data.current_frame].position = math3d.ref(iom.get_position(eid))
        camera_mgr.update_frustrum(eid)
    elseif world[eid].light_type then
        light_gizmo.update()
    end
end

local function on_rotate_dirty(eid, rot)
    local oldRot = math3d.totable(iom.get_rotation(eid))
    local newRot = {rot[1], rot[2], rot[3]}
    local quat = math3d.quaternion(newRot)
    gizmo:set_rotation(quat)
    world:pub {"EntityEvent", "rotate", eid, oldRot, newRot}
    if world[eid].camera then
        local frames = camera_mgr.get_recorder_frames(eid)
        frames[camera_ui_data.current_frame].rotation = math3d.ref(quat)
        camera_mgr.update_frustrum(eid)
    elseif world[eid].light_type then
        light_gizmo.update()
    end
end

local function on_scale_dirty(eid, scale)
    if world[eid].camera then
        
    else
        local oldScale = math3d.totable(iom.get_scale(eid))
        gizmo:set_scale(scale)
        world:pub {"EntityEvent", "scale", eid, oldScale, {scale[1], scale[2], scale[3]}}
    end
end

local function show_light_property(eid)
    
    light_gizmo.remove_invalid_entity()

    imgui.cursor.Separator()
    imgui.widget.Text("color:")
    imgui.cursor.SameLine()
    if imgui.widget.ColorEdit("##lightcolor", light_ui_data.color) then
        ilight.set_color(eid, light_ui_data.color)
    end
    imgui.widget.Text("intensity:")
    imgui.cursor.SameLine()
    if imgui.widget.DragFloat("##intensity", light_ui_data.intensity) then
        ilight.set_intensity(eid, light_ui_data.intensity[1])
        light_gizmo.update_gizmo()
    end
    if world[eid].light_type ~= "directional" then
        imgui.widget.Text("range:")
        imgui.cursor.SameLine()
        if imgui.widget.DragFloat("##range", light_ui_data.range) then
            ilight.set_range(eid, light_ui_data.range[1])
            light_gizmo.update_gizmo()
        end
        if world[eid].light_type == "spot" then
            imgui.widget.Text("radian:")
            imgui.cursor.SameLine()
            if imgui.widget.DragFloat("##radian", light_ui_data.radian) then
                ilight.set_radian(eid, light_ui_data.radian[1])
                light_gizmo.update_gizmo()
            end
        end
    end
end

local function set_current_frame(eid, idx, force)
    if camera_ui_data.current_frame == idx and not force then return end
    camera_ui_data.current_frame = idx
    update_ui_data(eid)
    camera_mgr.set_frame(eid, idx)
end

local function show_camera_property(eid)
    if imgui.widget.TreeNode("Camera", imgui.flags.TreeNode { "DefaultOpen" }) then
        local what
        local value
        if imgui.widget.InputInt("Target", camera_ui_data.target) then
            if hierarchy:get_node(camera_ui_data.target[1]) then
                what = "target"
                value = camera_ui_data.target[1]
            end
        end
        if camera_ui_data.target ~= -1 then
            if imgui.widget.DragFloat("Dist", camera_ui_data.dist) then
                what = "dist"
                value = camera_ui_data.dist[1]
            end
        end
        if imgui.widget.DragFloat("FOV", camera_ui_data.field_of_view) then
            what = "fov"
            value = camera_ui_data.field_of_view[1]
        end
        if imgui.widget.DragFloat("Near", camera_ui_data.near_plane) then
            what = "near"
            value = camera_ui_data.near_plane[1]
        end
        if imgui.widget.DragFloat("Far", camera_ui_data.far_plane) then
            what = "far"
            value = camera_ui_data.far_plane[1]
        end
        imgui.cursor.Separator()
        if imgui.widget.Button("AddFrame") then
            local new_idx = camera_ui_data.current_frame + 1
            camera_mgr.add_recorder_frame(eid, new_idx)
            set_current_frame(eid, new_idx, true)
            local frames = camera_mgr.get_recorder_frames(eid)
            camera_ui_data.duration[new_idx] = {frames[new_idx].duration}
        end
        local frames = camera_mgr.get_recorder_frames(eid)
        if #frames > 1 then
            imgui.cursor.SameLine()
            if imgui.widget.Button("DeleteFrame") then
                camera_mgr.delete_recorder_frame(eid, camera_ui_data.current_frame)
                table.remove(camera_ui_data.duration, camera_ui_data.current_frame)
                if camera_ui_data.current_frame > #frames then
                    set_current_frame(eid, #frames)
                end
            end
            imgui.cursor.SameLine()
            if imgui.widget.Button("Play") then
                camera_mgr.play_recorder(eid)
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
                if imgui.widget.Selectable(i, camera_ui_data.current_frame == i) then
                    set_current_frame(eid, i)
                end
                imgui.cursor.NextColumn()
                if imgui.widget.DragFloat("##"..i, camera_ui_data.duration[i]) then
                    frames[i].duration = camera_ui_data.duration[i][1]
                end
                imgui.cursor.NextColumn()
            end
            imgui.cursor.Columns(1)
        end

        if what then
            world:pub {"CameraEdit", what, eid, value}
        end
        imgui.widget.TreePop()
    end
end

function m.show()
    local viewport = imgui.GetMainViewport()
    imgui.windows.SetNextWindowPos(viewport.WorkPos[1] + viewport.WorkSize[1] - uiconfig.PropertyWidgetWidth, viewport.WorkPos[2] + uiconfig.ToolBarHeight, 'F')
    imgui.windows.SetNextWindowSize(uiconfig.PropertyWidgetWidth, viewport.WorkSize[2] - uiconfig.BottomWidgetHeight - uiconfig.ToolBarHeight, 'F')
    
    local current_eid = gizmo.target_eid
    for _ in uiutils.imgui_windows("Inspector", imgui.flags.Window { "NoCollapse", "NoClosed" }) do
        if current_eid and world[current_eid] then
            if base_ui_data.current_eid ~= current_eid then
                base_ui_data.current_eid = current_eid
                if world[current_eid].camera then
                    set_current_frame(current_eid, 1, true)
                end
                update_ui_data(current_eid)
            end
            local template = hierarchy:get_template(current_eid)
            if template and template.filename then
                imgui.widget.Text("Prefab :")
                imgui.cursor.SameLine()
                imgui.widget.Text(template.filename)
            end
            imgui.widget.Text("Name:")
            imgui.cursor.SameLine()
            imgui.cursor.PushItemWidth(-1)
            if imgui.widget.InputText("##Name", base_ui_data.name) then
                local name = tostring(base_ui_data.name.text)
                world[current_eid].name = name
                world:pub {"EntityEvent", "name", current_eid, name}
            end
            imgui.cursor.PopItemWidth()
            if imgui.widget.TreeNode("Transform", imgui.flags.TreeNode { "DefaultOpen" }) then
                imgui.widget.Text("Position:")
                imgui.cursor.SameLine()
                if imgui.widget.DragFloat("##Position", base_ui_data.pos) then
                    on_position_dirty(current_eid, base_ui_data.pos)
                end
                imgui.widget.Text("Rotate:")
                imgui.cursor.SameLine()
                if imgui.widget.DragFloat("##Rotate", base_ui_data.rot) then
                    on_rotate_dirty(current_eid, base_ui_data.rot)
                end
                imgui.widget.Text("Scale:")
                imgui.cursor.SameLine()
                if imgui.widget.DragFloat("##Scale", base_ui_data.scale) then
                    on_scale_dirty(current_eid, base_ui_data.scale)
                end
                imgui.widget.TreePop()
            end
            if world[current_eid].camera then
                show_camera_property(current_eid)
            elseif world[current_eid].light_type then
                show_light_property(current_eid)
            else
                material_panel.show(current_eid)
            end
        end
    end
end

return function(w)
    world = w
    iom             = world:interface "ant.objcontroller|obj_motion"
    icamera         = world:interface "ant.camera|camera"
    ilight          = world:interface "ant.render|light"
    worldedit       = import_package "ant.editor".worldedit(world)
    camera_mgr      = require "camera_manager"(world)
    material_panel  = require "widget.material"(world)
    gizmo           = require "gizmo.gizmo"(world)
    light_gizmo     = require "gizmo.light"(world)
    return m
end