local ecs = ...
local world = ecs.world
local w = world.w
local imgui     = require "imgui"
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
    local viewport = imgui.GetMainViewport()
    imgui.windows.SetNextWindowPos(viewport.WorkPos[1] + viewport.WorkSize[1] - uiconfig.PropertyWidgetWidth, viewport.WorkPos[2] + uiconfig.ToolBarHeight, 'F')
    imgui.windows.SetNextWindowSize(uiconfig.PropertyWidgetWidth, viewport.WorkSize[2] - uiconfig.BottomWidgetHeight - uiconfig.ToolBarHeight, 'F')
    for _ in uiutils.imgui_windows("GridMesh", imgui.flags.Window { "NoCollapse", "NoClosed" }) do
        local title = "CreateGridMesh"
        if imgui.widget.Button("Create") then
            imgui.windows.OpenPopup(title)
        end

        local change, opened = imgui.windows.BeginPopupModal(title, imgui.flags.Window{"AlwaysAutoResize"})
        if change then
            local label = "Grid Size : "
            imgui.widget.Text(label)
            imgui.cursor.SameLine()
            if imgui.widget.DragFloat("##"..label, grid_size_ui) then
            
            end
            
            label = "      Row : "
            imgui.widget.Text(label)
            imgui.cursor.SameLine()
            if imgui.widget.DragInt("##"..label, grid_row_ui) then

            end
            
            label = "      Col : "
            imgui.widget.Text(label)
            imgui.cursor.SameLine()
            if imgui.widget.DragInt("##"..label, grid_col_ui) then

            end
            
            if imgui.widget.Button("    OK    ") then
                world:pub {"GridMesh", "create", grid_size_ui[1], grid_row_ui[1], grid_col_ui[1]}
                imgui.windows.CloseCurrentPopup()
            end
            imgui.cursor.SameLine()
            if imgui.widget.Button("  Cancel  ") then
                imgui.windows.CloseCurrentPopup()
            end
            imgui.windows.EndPopup()
        end
        imgui.cursor.SameLine()
        if imgui.widget.Button("Load") then
            local path = uiutils.get_open_file_path("Lua", "lua")
            if path then
                current_grid:load(path)
            end
        end
        if current_grid then
            imgui.widget.PropertyLabel("Show")
            if imgui.widget.Checkbox("##Show", visible_ui) then
                current_grid:show(visible_ui[1])
            end
            
            imgui.widget.PropertyLabel("Brush")
            if imgui.widget.BeginCombo("##Brush", {current_label, flags = imgui.flags.Combo {}}) then
                for index, label in ipairs(brush_def.label) do
                    if imgui.widget.Selectable(label, current_label == label) then
                        current_label = label
                        local color = brush_def.color[index]
                        world:pub {"GridMesh", "brushcolor", index, color}
                        current_color = colori2f(color)
                        update_color()
                    end
                end
                imgui.widget.EndCombo()
            end

            local color_label = "BrushColor"
            if imgui.widget.ColorEdit("##"..color_label, brush_color_ui) then
                update_color()
            end

            local brush_size_label = "BrushSize"
            imgui.widget.PropertyLabel(brush_size_label)
            if imgui.widget.DragInt("##"..brush_size_label, brush_size_ui) then
                world:pub {"GridMesh", "brushsize", brush_size_ui[1]}
            end
            
            if current_grid.data then
                if imgui.widget.Button("Save") then
                    current_grid:save(current_grid.filename)
                end
                if current_grid.filename then
                    imgui.cursor.SameLine()
                    if imgui.widget.Button("SaveAs") then
                        current_grid:save()
                    end
                end
            end
        end
    end
end

return m
