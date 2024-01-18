local ecs = ...
local world = ecs.world
local w = world.w
local ImGui     = import_package "ant.imgui"
local uiconfig  = require "widget.config"
local uiutils   = require "widget.utils"
local brush_def = require "brush_def"
local m = {}

local grid_size_ui = {0.2, speed = 0.1, min = 0.1, max = 10}
local grid_row_ui = {2, speed = 1, min = 2, max = 1000}
local grid_col_ui = {2, speed = 1, min = 2, max = 1000}
local visible_ui = {true}
local current_grid
local current_label = "default"

function m.set_grid(grid)
    current_grid = grid
    current_grid.brush = brush_def.color
    visible_ui[1] = grid.visible
end

local function colori2f(ic)
    return {(ic & 0xFF) / 255.0, ((ic & 0x0000FF00) >> 8) / 255.0, ((ic & 0x00FF0000) >> 16) / 255.0, ((ic & 0xFF000000) >> 24) / 255.0}
end

local current_color = colori2f(brush_def.color[1])
local brush_color_ui = {current_color[1], current_color[2], current_color[3], current_color[4]}
local brush_size_ui = {1, min = 1, max = 8, speed = 1}

local function update_color()
    brush_color_ui[1] = current_color[1]
    brush_color_ui[2] = current_color[2]
    brush_color_ui[3] = current_color[3]
    brush_color_ui[4] = current_color[4]
end

function m.show()
    local viewport = ImGui.GetMainViewport()
    ImGui.SetNextWindowPos(viewport.WorkPos[1] + viewport.WorkSize[1] - uiconfig.PropertyWidgetWidth, viewport.WorkPos[2] + uiconfig.ToolBarHeight, 'F')
    ImGui.SetNextWindowSize(uiconfig.PropertyWidgetWidth, viewport.WorkSize[2] - uiconfig.BottomWidgetHeight - uiconfig.ToolBarHeight, 'F')
    if ImGui.Begin("GridMesh", ImGui.Flags.Window { "NoCollapse", "NoClosed" }) then
        local title = "CreateGridMesh"
        if ImGui.Button("Create") then
            ImGui.OpenPopup(title)
        end

        local change, opened = ImGui.BeginPopupModal(title, ImGui.Flags.Window{"AlwaysAutoResize"})
        if change then
            local label = "Grid Size : "
            ImGui.Text(label)
            ImGui.SameLine()
            if ImGui.DragFloat("##"..label, grid_size_ui) then
            
            end
            
            label = "      Row : "
            ImGui.Text(label)
            ImGui.SameLine()
            if ImGui.DragInt("##"..label, grid_row_ui) then

            end
            
            label = "      Col : "
            ImGui.Text(label)
            ImGui.SameLine()
            if ImGui.DragInt("##"..label, grid_col_ui) then

            end
            
            if ImGui.Button("    OK    ") then
                world:pub {"GridMesh", "create", grid_size_ui[1], grid_row_ui[1], grid_col_ui[1]}
                ImGui.CloseCurrentPopup()
            end
            ImGui.SameLine()
            if ImGui.Button("  Cancel  ") then
                ImGui.CloseCurrentPopup()
            end
            ImGui.EndPopup()
        end
        ImGui.SameLine()
        if ImGui.Button("Load") then
            local path = uiutils.get_open_file_path("Lua", "lua")
            if path then
                current_grid:load(path)
            end
        end
        if current_grid then
            ImGui.PropertyLabel("Show")
            if ImGui.Checkbox("##Show", visible_ui) then
                current_grid:show(visible_ui[1])
            end
            
            ImGui.PropertyLabel("Brush")
            if ImGui.BeginCombo("##Brush", {current_label, flags = ImGui.Flags.Combo {}}) then
                for index, label in ipairs(brush_def.label) do
                    if ImGui.Selectable(label, current_label == label) then
                        current_label = label
                        local color = brush_def.color[index]
                        world:pub {"GridMesh", "brushcolor", index, color}
                        current_color = colori2f(color)
                        update_color()
                    end
                end
                ImGui.EndCombo()
            end

            local color_label = "BrushColor"
            if ImGui.ColorEdit("##"..color_label, brush_color_ui) then
                update_color()
            end

            local brush_size_label = "BrushSize"
            ImGui.PropertyLabel(brush_size_label)
            if ImGui.DragInt("##"..brush_size_label, brush_size_ui) then
                world:pub {"GridMesh", "brushsize", brush_size_ui[1]}
            end
            
            if current_grid.data then
                if ImGui.Button("Save") then
                    current_grid:save(current_grid.filename)
                end
                if current_grid.filename then
                    ImGui.SameLine()
                    if ImGui.Button("SaveAs") then
                        current_grid:save()
                    end
                end
            end
        end
    end
    ImGui.End()
end

return m
