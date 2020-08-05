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
local localSpace = {}
local viewStartY = uiconfig.WidgetStartY + uiconfig.ToolBarHeight

local uiData = {
    eid = {0, flags = imgui.flags.InputText{ "ReadOnly" }},
    name = {text = "noname"},
    pos = {0,0,0},
    rot = {0,0,0},
    scale = {1,1,1},
    state = {0},
    material = {text = "nomaterial"},
    mesh = {text = "nomesh"}
}

local function update_ui_transform(eid)
    if not eid then
        return
    end
    local s, r, t = math3d.srt(iom.srt(eid))
    local Pos = math3d.totable(t)
    uiData.pos[1] = Pos[1]
    uiData.pos[2] = Pos[2]
    uiData.pos[3] = Pos[3]

    local Rot = math3d.totable(math3d.quat2euler(r))
    uiData.rot[1] = math.deg(Rot[1])
    uiData.rot[2] = math.deg(Rot[2])
    uiData.rot[3] = math.deg(Rot[3])

    local Scale = math3d.totable(s)
    uiData.scale[1] = Scale[1]
    uiData.scale[2] = Scale[2]
    uiData.scale[3] = Scale[3]
end

local function on_select(eid)
    uiData.eid[1] = eid
    uiData.name.text = world[eid].name
    update_ui_transform(eid)
    uiData.state[1] = world[eid]._rendercache.state
    -- uiData.material.text = world[eid].material.filename
    -- uiData.mesh.text = world[eid].mesh.filename
end

local gizmo

function m.set_gizmo(obj)
    gizmo = obj
end

function m.update_template_tranform(eid)
    if not eid then return end
    local template = prefab_view:get_template(eid)
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
    update_ui_transform(eid)
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
            if uiData.eid[1] ~= gizmo.target_eid then
                on_select(gizmo.target_eid)
            end
            imgui.widget.Text("EID :")
            imgui.cursor.SameLine()
            imgui.widget.Text(uiData.eid[1])
            local template = prefab_view:get_template(uiData.eid[1])
            if template and template.filename then
                imgui.widget.Text("Prefab :")
                imgui.cursor.SameLine()
                imgui.widget.Text(template.filename)
            end

            if imgui.widget.InputText("Name", uiData.name) then
                local name = tostring(uiData.name.text)
                world[uiData.eid[1]].name = name
                world:pub {"EntityEvent", "name", uiData.eid[1], name}
            end

            if imgui.widget.TreeNode("Transform", imgui.flags.TreeNode { "DefaultOpen" }) then
                if imgui.widget.InputFloat("Position", uiData.pos) then
                    oldPos = math3d.totable(iom.get_position(uiData.eid[1]))
                    gizmo:set_position(uiData.pos)
                end
                if imgui.widget.InputFloat("Rotate", uiData.rot) then
                    oldRot = math3d.totable(iom.get_rotation(uiData.eid[1]))
                    gizmo:set_rotation(uiData.rot)
                end
                if imgui.widget.InputFloat("Scale", uiData.scale) then
                    oldScale = math3d.totable(iom.get_scale(uiData.eid[1]))
                    gizmo:set_scale(uiData.scale)
                end
                imgui.widget.TreePop()
            end
            if imgui.widget.TreeNode("Material", imgui.flags.TreeNode { "DefaultOpen" }) then
                if imgui.widget.InputText("mtlFile", uiData.material) then
                    world[uiData.eid[1]].mesh = tostring(uiData.material.text)
                end
                if imgui.widget.BeginDragDropTarget() then
                    local payload = imgui.widget.AcceptDragDropPayload("DragFile")
                    if payload then
                        print(payload)
                    end
                    imgui.widget.EndDragDropTarget()
                end
                imgui.widget.TreePop()
            end
            -- if imgui.widget.InputText("Name", uiData.mesh) then
            --     world[uiData.eid[1]].mesh = tostring(uiData.mesh.text)
            -- end
        end
    end

    if oldPos then
        world:pub {"EntityEvent", "move", gizmo.target_eid, oldPos, {uiData.pos[1], uiData.pos[2], uiData.pos[3]}}
        oldPos = nil
    elseif oldRot then
        world:pub {"EntityEvent", "rotate", gizmo.target_eid, oldRot, {uiData.rot[1], uiData.rot[2], uiData.rot[3]}}
        oldRot = nil
    elseif oldScale then
        world:pub {"EntityEvent", "scale", gizmo.target_eid, oldScale, {uiData.scale[1], uiData.scale[2], uiData.scale[3]}}
        oldScale = nil
    end
end

return function(w)
    world = w
    iom = world:interface "ant.objcontroller|obj_motion"
    worldedit = import_package "ant.editor".worldedit(world)
    return m
end