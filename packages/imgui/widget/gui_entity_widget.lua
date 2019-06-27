local imgui     = require "imgui_wrap"
local widget    = imgui.widget
local flags     = imgui.flags
local windows   = imgui.windows
local util      = imgui.util
local cursor    = imgui.cursor
local enum      = imgui.enum
local IO      = imgui.IO
local hub       = import_package "ant.editor".hub

local factory = require "widget.gui_basecomponent_widget"

local render_base_component
local render_alias_component
local render_array_component
local render_map_component
local render_component
local render_com_component
local is_direct_type
local update

local DefaultOpen = flags.TreeNode.DefaultOpen

function render_base_component(parent_tbl,com_name,component_data,schema,alias_name)
    local com_schema = schema[com_name]
    local typ = com_schema.type
    local base_widget = factory[com_name]
    local value = component_data
    local ui_cache = parent_tbl.__ui_cache or {}
    parent_tbl.__ui_cache = ui_cache
    local change,new_value =  base_widget(ui_cache,alias_name,value)
        --todo something
    if change then
        parent_tbl[alias_name] = new_value
        local eid = parent_tbl.__id
        if not eid then
            --entity has nor __id,but has __entity_id
            eid = parent_tbl.__entity_id
        end
        --todo
        -- entity_property_builder.notify_modify(eid,parent_tbl.__id,alias_name,value)
        -- return true -- if return nil, modify will be ignored
    end
    return true
end

function render_alias_component(parent_tbl,com_name,component_data,schema,alias_name)
    local com_schema = schema[com_name]
    local map_com_type = com_schema.type
    return render_component(parent_tbl,map_com_type,component_data,schema,alias_name)
end

function render_array_component(parent_tbl,com_name,component_data,schema,alias_name)
    local com_schema = schema[com_name]
    local map_com_type = com_schema.type
    local array_param = com_schema.array
    local typ = map_com_type
    if typ == nil or typ == "primtype" then
        typ = com_name
    end
    if widget.TreeNode(alias_name) then
        for index,data in ipairs(component_data) do
            render_component(component_data,typ,data,schema,index)
        end
        widget.TreePop()
    end
    return true
end

function render_map_component(parent_tbl,com_name,component_data,schema,alias_name)
    local com_schema = schema[com_name]
    local map_com_type = com_schema.type
    local map = com_schema.map
    if widget.TreeNode(alias_name,DefaultOpen) then
        for child_name,data in pairs(component_data) do
            render_component(component_data,com_name,data,schema,child_name)
        end
        widget.TreePop()
    end
    return true
end

function render_com_component( parent_tbl,com_name,component_data,schema,alias_name )
    if widget.TreeNode(alias_name,DefaultOpen) then
        local com_schema = schema[com_name]
        local count = 0
        for _,sub_schema in ipairs(com_schema) do
            local sub_data = component_data[sub_schema.name]
            if component_data[sub_schema.name] then
                local child_ctrl = nil
                if not sub_schema.type then
                    render_com_component(component_data,sub_schema.type,sub_data,schema,sub_schema.name)
                elseif sub_schema.array then -- has type & array
                    render_array_component(component_data,sub_schema.type,sub_data,schema,sub_schema.name)
                elseif sub_schema.map then -- has type & map
                    render_map_component(component_data,sub_schema.type,sub_data,schema,sub_schema.name)
                elseif  is_direct_type(sub_schema.type)  then
                    render_base_component(component_data,sub_schema.type,sub_data,schema,sub_schema.name)
                else -- has type & not array
                    render_component(component_data,sub_schema.type,sub_data,schema,sub_schema.name)
                end
                count = count + 1
            end
        end
        widget.TreePop()
    end
    return true
end

function render_component(parent_tbl,com_name,component_data,schema,alias_name)
    local com_schema = schema[com_name]
    if not com_schema then
        widget.Text("not found component schema:"..com_name)
        return false
    elseif not com_schema.type then
        return render_com_component(parent_tbl,com_name,component_data,schema,alias_name)
    elseif com_schema.array then
        return render_array_component(parent_tbl,com_name,component_data,schema,alias_name)
    elseif com_schema.map then -- has type & map
        return render_map_component(component_data,sub_schema.type,sub_data,schema,sub_schema.name)
    elseif is_direct_type(com_name) then
        return render_base_component(parent_tbl,com_name,component_data,schema,alias_name)
    else -- has type & not array
        return render_alias_component(parent_tbl,com_name,component_data,schema,alias_name)
    end
end

function is_direct_type(type)
    return factory[type]
end

function update(eid,entity,schema)
    entity.__entity_id = eid
    for com_name,component_data in pairs(entity) do
        if com_name ~= "__entity_id" and com_name ~= "__ui_cache" then
        -- if widget.CollapsingHeader(com_name.."##RootComponent") then
            if render_component(entity,com_name,component_data,schema,com_name) then
            -- end
                cursor.Separator()
            end
        end
    end
end

return {update = update}