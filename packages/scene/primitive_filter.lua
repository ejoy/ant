local ecs = ...
local world = ecs.world

-- local w = world.w

-- local ipf = ecs.interface "iprimitive_filter"
-- function ipf.names()
--     return LAYER_NAMES
-- end

-- function ipf.layers(filter_name)
--     return assert(LAYERS[filter_name])
-- end

-- function ipf.is_valid_layer(filter_name, ln)
--     for _, n in ipairs(LAYERS[filter_name]) do
--         if n == ln then
--             return true
--         end
--     end
-- end

-- function ipf.sync_filter(filter_name)
--     local t = {}
--     for _, n in ipairs(LAYERS[filter_name]) do
--         t[#t+1] = n .. "?out"
--     end

--     return table.concat(t, ' ')
-- end

-- local function clear_tag(filter_name, o)
--     local t = {
--         filter_name .. "?out"
--     }
-- 	for _, n in ipairs(ipf.layers(filter_name)) do
-- 		o[n] = false
--         t[#t+1] = n .. "?out"
-- 	end
--     return table.concat(t, " ")
-- end

-- function ipf.update_filter_tag(filter_name, layername, layervalue, o)
--     if layervalue == nil then
--         error "should not be 'nil'"
--     end
--     local sf = clear_tag(filter_name, o)
--     o[layername] = layervalue
-- 	o[filter_name] = layervalue
--     w:sync(sf, o)
-- end