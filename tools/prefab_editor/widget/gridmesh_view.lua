local imgui     = require "imgui"
local math3d    = require "math3d"
local hierarchy = require "hierarchy"
local uiconfig  = require "widget.config"
local uiutils   = require "widget.utils"
local uiproperty = require "widget.uiproperty"
local brush_def = require "brush_def"
local world
local prefab_mgr
local m = {}
local interp_type = {"linear", "const"}
local current_emitter_eid

local property = {}

local emitter_data

local function update_emitter()
    local new_eid = prefab_mgr:recreate_entity(current_emitter_eid)
    m.set_emitter(new_eid)
end

local function update_panel(props)
    for _, prop in ipairs(props) do
        prop:update()
    end
end

local function show_panel(props)
    for _, prop in ipairs(props) do
        prop:show()
    end
end

local function fcolor_property(data_source, key)
    local dim = #data[key]
    return uiproperty.Color({label = key, dim = dim, flags = (dim == 4) and imgui.flags.ColorEdit{"Float"} or imgui.flags.ColorEdit{"NoAlpha", "Float"}}, {
        setter = function(v)
            data_source[key] = v
            update_emitter()
        end,
        getter = function() return data_source[key] end
    })
end

local function icolor_property(data_source, key)
    local dim = #data_source[key]
    local data = data_source[key]
    return uiproperty.Color({label = key, dim = dim, flags = (dim == 4) and imgui.flags.ColorEdit{"Uint8"} or imgui.flags.ColorEdit{"NoAlpha", "Uint8"}}, {
        setter = function(value)
            for i, vf in ipairs(value) do
                data[i] = math.floor(vf * 255)
            end
            update_emitter()
        end,
        getter = function()
            local fc = {}
            for i, vi in ipairs(data) do
                fc[i] = vi / 255.0
            end
            return fc
        end
    })
end

local function number_property(data_source, key, is_int, minv, maxv, speedv)
    local pro_creator = is_int and uiproperty.Int or uiproperty.Float
    return pro_creator({label = key, dim = type(data_source[key]) == "table" and #data_source[key] or 1, min = minv, max = maxv, speed = speedv}, {
        setter = function(v)
            data_source[key] = v
            update_emitter()
        end,
        getter = function() return data_source[key] end
    })
end

local function interp_type_property(data_source, key)
    return uiproperty.Combo({label = key, options = interp_type}, {
        setter = function(v)
            data_source[key] = v
            update_emitter()
        end,
        getter = function() return data_source[key] end
    })
end

local function create_interp_panel(data_source, group_name, is_int, min, max)
    return uiproperty.Group({label = group_name}, {
        interp_type_property(data_source, "interp_type"),
        number_property(data_source, "minv", is_int, min, max),
        number_property(data_source, "maxv", is_int, min, max)
    })
end

local function create_color_interp_panel(data_source, group_name)
    return uiproperty.Group({label = group_name}, {
        interp_type_property(data_source, "interp_type"),
        icolor_property(data_source, "minv"),
        icolor_property(data_source, "maxv")
    })
end

local function create_emitter_panel()
    property = {} 
    property[#property + 1] = create_interp_panel(emitter_data.lifetime, "lifetime")
    local spawn_property = {}
    spawn_property[#spawn_property + 1] = number_property(emitter_data.spawn, "count", true, 1, 100)
    spawn_property[#spawn_property + 1] = number_property(emitter_data.spawn, "rate", false, 0.1, 10.0, 0.1)
    for key, item in pairs(emitter_data.spawn) do
        if key == "init_color" then
            local source_data = emitter_data.spawn[key]["RGBA"]
            spawn_property[#spawn_property + 1] = uiproperty.Group({label = key}, {
                interp_type_property(source_data, "interp_type"),
                icolor_property(source_data, "value")
            })
        elseif key == "color_over_life" then
            spawn_property[#spawn_property + 1] = uiproperty.Group({label = key}, {
                create_color_interp_panel(emitter_data.spawn[key]["RGB"], "RGB"),
                create_interp_panel(emitter_data.spawn[key]["A"], "A", true, 0, 255)
            })
        elseif key == "subuv_index" then
            spawn_property[#spawn_property + 1] = uiproperty.Group({label = key}, {
                number_property(emitter_data.spawn[key], "dimension", true, 1),
                create_interp_panel(emitter_data.spawn[key]["rate"], "rate")
            })
        elseif key == "count" or key =="rate" then
            --
        elseif key == "init_lifetime" then
            spawn_property[#spawn_property + 1] = create_interp_panel(emitter_data.spawn[key], key, false, 0)
        else
            spawn_property[#spawn_property + 1] = create_interp_panel(emitter_data.spawn[key], key)
        end
    end
    property[#property + 1] = uiproperty.Group({label = "spawn"}, spawn_property)
    update_panel(property)
end

function m.set_emitter(emitter_eid)
    current_emitter_eid = emitter_eid
    local tp = hierarchy:get_template(emitter_eid)
    emitter_data = tp.template.data.emitter
    create_emitter_panel()
end

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
    return {((ic & 0xFF000000) >> 24) / 255.0, ((ic & 0x00FF0000) >> 16) / 255.0, ((ic & 0x0000FF00) >> 8) / 255.0, (ic & 0xFF) / 255.0 }
end

local current_color = colori2f(brush_def.color[1])
local brush_color_ui = {current_color[1], current_color[2], current_color[3], current_color[4]}

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
            local path = uiutils.get_open_file_path("Lua", ".lua")
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
            --imgui.widget.PropertyLabel(color_label)
            if imgui.widget.ColorEdit("##"..color_label, brush_color_ui) then
                update_color()
                --world:pub {"GridMesh", "brushcolor", brush_color_ui[1], brush_color_ui[2], brush_color_ui[3], brush_color_ui[4]}
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

return function(w)
    world = w
    return m
end