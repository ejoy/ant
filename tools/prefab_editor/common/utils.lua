local utils = {}
local function do_deep_copy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[do_deep_copy(orig_key)] = do_deep_copy(orig_value)
        end
        setmetatable(copy, do_deep_copy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end
function utils.deep_copy(orig)
    return do_deep_copy(orig)
end

return utils