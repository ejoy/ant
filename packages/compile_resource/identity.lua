local util = {} util.__index = util

local function find_item(items, startidx, name)
    for i=startidx, #items do
        if items[i] == name then
            return true
        end
    end
end

function util.parse(identity)
    local items = {}
    for item in identity:gmatch "[^_]+" do
        items[#items+1] = item
    end
    return {
        platform = items[1],
        renderer = items[2],
        homogeneous_depth = find_item(items, 3, "hd"),
        origin_bottom_left = find_item(items, 3, "obl"),
    }
end

return util