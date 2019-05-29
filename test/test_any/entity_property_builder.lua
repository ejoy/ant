local log = log and log(...) or print

require "iupluacontrols"

local iupcontrols   = import_package "ant.iupcontrols"
local editor = import_package "ant.editor"
local math = import_package "ant.math"
local ms = math.stack
local su = import_package "ant.serialize"
local factory = require "entity_value_controller_factory"

local entity_property_builder = {}

--todo pass a modify function to builder
function entity_property_builder.notify_modify(eid,id,key,value)
    local entity_property_hub = require "entity_property_hub"
    entity_property_hub.publish_modify_component(eid,id,key,value)
end

function entity_property_builder.build_primtype_component(parent_tbl,com_name,component_data,schema,alias_name)
    local com_schema = schema[com_name]
    local typ = com_schema.type
    local function modify_function(value)
        print(">>>>>>>>>>>>>>>>>>>>>")
        print_a("    before:",parent_tbl)
        print_a("    modify:",alias_name,value)
        parent_tbl[alias_name] = value
        print_a("    after:",parent_tbl)
        print("<<<<<<<<<<<<<<<<<<")
        local eid = nil
        if not parent_tbl.__id then
            --entity has nor __id,but has __entity_id
            eid = parent_tbl.__entity_id
        end
        entity_property_builder.notify_modify(eid,parent_tbl.__id,alias_name,value)
        return true -- if return nil, modify will be ignored
    end
    local builder = factory[com_name]
    local value = component_data
    -- if com_schema.method and com_schema.method.save then
    --     value = com_schema.method.save(value)
    -- end
    local value_ctrl = builder(alias_name,value,modify_function)
    
    return value_ctrl
end

function entity_property_builder.build_alias_component(parent_tbl,com_name,component_data,schema,alias_name)
    local com_schema = schema[com_name]
    local map_com_type = com_schema.type
    return entity_property_builder.build_component(parent_tbl,map_com_type,component_data,schema,alias_name)
end

function entity_property_builder.build_array_component(parent_tbl,com_name,component_data,schema,alias_name)
    local com_schema = schema[com_name]
    local map_com_type = com_schema.type
    local array_param = com_schema.array
    local vbox_ctrl = iup.vbox {
        iup.label { title = "["..tostring(alias_name).."]" }
    }
    local typ = map_com_type
    if typ == nil or typ == "primtype" then
        typ = com_name
    end
    for index,data in ipairs(component_data) do
        local child_ctrl = entity_property_builder.build_component(component_data,typ,data,schema,index)
        iup.Append(vbox_ctrl,child_ctrl)
    end
    return vbox_ctrl
end

function entity_property_builder.build_map_component(parent_tbl,com_name,component_data,schema,alias_name)
    local com_schema = schema[com_name]
    local map_com_type = com_schema.type
    local map = com_schema.map
    local vbox_ctrl = iup.vbox {
        iup.label { title = "["..tostring(alias_name).."]" }
    }
    -- normal table
    for child_name,data in pairs(component_data) do
        local child_ctrl = entity_property_builder.build_component(component_data,com_name,data,schema,child_name)
        iup.Append(vbox_ctrl,child_ctrl)
    end
    -- listize table
    -- for _,data in pairs(component_data) do
    --     local child_ctrl = entity_property_builder.build_component(component_data,com_name,data[2],schema,data[1])
    --     iup.Append(vbox_ctrl,child_ctrl)
    -- end
    return vbox_ctrl
end


function entity_property_builder.build_com_component(parent_tbl,com_name,component_data,schema,alias_name)
    local container = iup.vbox {
    }
    local expander = iup.expander {
        iup.hbox{
            iup.label {title = " ",rastersize="20x5"},
            iup.backgroundbox {
                container,
            },
        },
        
        title = tostring(alias_name),
    }
    local com_schema = schema[com_name]
    local count = 0
    for _,sub_schema in ipairs(com_schema) do
        local sub_data = component_data[sub_schema.name]
        if component_data[sub_schema.name] then
            local child_ctrl = nil
            if not sub_schema.type then
                child_ctrl = entity_property_builder.build_com_component(component_data,sub_schema.type,sub_data,schema,sub_schema.name)
            elseif sub_schema.array then -- has type & array
                child_ctrl = entity_property_builder.build_array_component(component_data,sub_schema.type,sub_data,schema,sub_schema.name)
            elseif sub_schema.map then -- has type & map
                child_ctrl = entity_property_builder.build_map_component(component_data,sub_schema.type,sub_data,schema,sub_schema.name)
            elseif  entity_property_builder.is_direct(sub_schema.type)  then
                child_ctrl = entity_property_builder.build_primtype_component(component_data,sub_schema.type,sub_data,schema,sub_schema.name)
            else -- has type & not array
                child_ctrl = entity_property_builder.build_component(component_data,sub_schema.type,sub_data,schema,sub_schema.name)
            end
            iup.Append(container,child_ctrl)
            count = count + 1
        end
    end
    if count == 0 then
        iup.Append(container,iup.label {title = "[Empty]"})
    end
    return expander
end

function entity_property_builder.build_component(parent_tbl,com_name,component_data,schema,alias_name)
    local com_schema = schema[com_name]
    local controller = nil
    if not com_schema then
        return iup.label({title=com_name})
    end
    if not com_schema.type then
        controller = entity_property_builder.build_com_component(parent_tbl,com_name,component_data,schema,alias_name)
    elseif com_schema.array then -- has type & array
        controller = entity_property_builder.build_array_component(parent_tbl,com_name,component_data,schema,alias_name)
    elseif com_schema.map then -- has type & map
        child_ctrl = entity_property_builder.build_map_component(component_data,sub_schema.type,sub_data,schema,sub_schema.name)
    elseif entity_property_builder.is_direct(com_name) then
        controller = entity_property_builder.build_primtype_component(parent_tbl,com_name,component_data,schema,alias_name)
    else -- has type & not array
        controller = entity_property_builder.build_alias_component(parent_tbl,com_name,component_data,schema,alias_name)
    end
    return controller
end

function entity_property_builder.is_direct(type)
    return factory[type]
end

--container:iup container
--entity:...
--schema:world._schema
function entity_property_builder.build_enity(container,eid,entity,schema)
    
    for com_name,component_data in pairs( entity ) do
        local iup_item = entity_property_builder.build_component(entity,com_name,component_data,schema,com_name)
        iup.Append(container,iup_item)
    end
    entity.__entity_id = eid
    iup.Append(container,iup.fill {})

end

return entity_property_builder