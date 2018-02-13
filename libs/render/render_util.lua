local util = {}

function util.for_each_comp(w, comp_names, op)
    for _, eid in w:each(comp_names[1]) do
        local entity = w[eid]
        if entity ~= nil then
            local function is_entity_have_components(beg_idx, end_idx)
                while beg_idx <= end_idx do
                    if entity[comp_names[beg_idx]] == nil then
                        return false
                    end
                    beg_idx = beg_idx + 1
                end
                return true
            end
        
            if is_entity_have_components(2, #comp_names) then
                op(entity)
            end
        end
    end
end

return util