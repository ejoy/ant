local accessor = {}

local write_type_map = {}

function accessor.write_lua(data,cfg)
    local tbl = {}
    table.insert(tbl,"return {\n")
    accessor.write_cfg(data,cfg,tbl,"\t")
    table.insert(tbl,"}\n")
    local str = table.concat(tbl)
    return str
end

function accessor.write_cfg(data,cfg,tbl,indent)
    for _,cfg_item in ipairs(cfg) do
        accessor.write_one_cfg(data,cfg_item,tbl,indent)
    end
end

function accessor.write_one_cfg(data,cfg_item,tbl,indent)
    local name = cfg_item.name
    
    local type_cfg_field = type(cfg_item.write or cfg_item.field )
    local cfg_field = cfg_item.write or cfg_item.field
        
    if type_cfg_field == "string" then
        local func = write_type_map[cfg_field]
        if not func then
            local last2letter = string.sub(cfg_field,-2,-1)
            local field_typ = nil
            if last2letter == "{}" then
                field_typ = "dict"
            elseif last2letter == "[]" then
                field_typ = "array"
            end
            if field_typ then
                local field_name = string.sub(cfg_field,1,-3)
                func = write_type_map[field_name]
                if func then
                    return func(data,cfg_item,field_typ,tbl,indent)
                end
                print(">>",cfg_field,last2letter,field_typ,field_name)
            end
            print(">>>",cfg_field,last2letter,field_typ,field_name)
            print("Unimplemented field type:",cfg_field)
            return
        end
        func(data,cfg_item,nil,tbl,indent)
    elseif type_cfg_field == "function" then
        local func = cfg_field
        func(data,cfg_item,tbl,indent)
    elseif type_cfg_field == "table" then
        local sub_data = data[cfg_item.name]
        if sub_data then
            table.insert(tbl,indent)
            table.insert(tbl,name)
            table.insert(tbl," = {\n")
            for _,citem in ipairs(cfg_item.field) do
                accessor.write_one_cfg(sub_data,citem,tbl,indent.."\t")
            end
            table.insert(tbl,indent)
            table.insert(tbl,"},\n")
        end
    else
        table.insert(tbl,indent)
        table.insert(tbl,name)
        table.insert(tbl," = ")
        table.insert(tbl,"[Unknown field type:"..type_cfg_field.."]")
        table.insert(tbl,",\n")
    end
end

function accessor.return_common_cfg_writer(func)
    return function(data,cfg_item,field_typ,tbl,indent)
        local name = cfg_item.name
        local val = data[name]
        if val ~= nil then
            table.insert(tbl,indent)
            table.insert(tbl,name)
            table.insert(tbl," = ")
            if field_typ == nil then
                table.insert(tbl,func(val))
                table.insert(tbl,",\n")
            elseif field_typ == "array" then
                assert(type(val) == "table","type is array,val is a "..type(val))
                table.insert(tbl,"{\n")
                local next_indent = indent.."\t"
                for i,v in ipairs(val) do
                    table.insert(tbl,next_indent)
                    table.insert(tbl,string.format('[%d] = ',i))
                    table.insert(tbl,func(v))
                    table.insert(tbl,",\n")
                end
                table.insert(tbl,indent)
                table.insert(tbl,"},\n")
            elseif field_typ == "dict" then
                assert(type(val) == "table","type is dict,val is a"..type(val))
                table.insert(tbl,"{\n")
                local next_indent = indent.."\t"
                for k,v in pairs(val) do
                    table.insert(tbl,next_indent)
                    if type(k) == "string" then
                        table.insert(tbl,string.format('%s = ',k))
                    else
                        table.insert(tbl,string.format('[%d] = ',k))
                    end
                    table.insert(tbl,func(v))
                    table.insert(tbl,",\n")
                end
                table.insert(tbl,indent)
                table.insert(tbl,"},\n")
            end
        end
    end
end

local boolean_fun = function(val)
    return val and "true" or "false"
end
accessor.write_cfg_of_boolean = accessor.return_common_cfg_writer(boolean_fun)

local string_fun = function(val)
    return string.format("\"%s\"",val)
end
accessor.write_cfg_of_string = accessor.return_common_cfg_writer(string_fun)

local number_fun = function(val)
    return tostring(val)
end
accessor.write_cfg_of_number = accessor.return_common_cfg_writer(number_fun)

write_type_map.boolean = accessor.write_cfg_of_boolean
write_type_map.string = accessor.write_cfg_of_string
write_type_map.number = accessor.write_cfg_of_number

--------test----------------------------------------
-- local TEST_CFG = {
--     {
--         name = "flags",
--         field = {
--             {
--                 name = "flip_uv",
--                 field = "boolean{}",
--             },
--             {
--                 name = "ib_32",
--                 field = "boolean[]",
--             },
--             {
--                 name = "invert_normal",
--                 field = "number",
--             },
--         }
--     },
--     {
--         name = "layout",
--         field = function(data,cfg_item,tbl,indent) --custom function
--             table.insert(tbl,indent)
--             table.insert(tbl,"layout = 1234,\n")
--         end,
--     },
-- }

-- local test_data = {
--     flags = {
--         flip_uv = {
--             a = true,
--             b = false,
--             c = true,
--         },
--         ib_32 = {
--             true,false,true,false,
--         },
--         invert_normal = 12313,
--     }
-- }

-- local a = accessor.write_lua(test_data,TEST_CFG)
-- print(a)

return {
    write_lua = accessor.write_lua,
}