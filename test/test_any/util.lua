local util = {}

function util.merge_config(tb,default_tb)
    local new_tb = {}
    for k,v in pairs(tb) do
        new_tb[k] = v
    end
    for k,v in pairs(default_tb) do
        new_tb[k] = new_tb[k] or v
    end
    return new_tb
end

return util