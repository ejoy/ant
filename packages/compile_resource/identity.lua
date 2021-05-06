local util = {} util.__index = util

function util.parse(identity)
    local items = {}
    for item in identity:gmatch "[^_]+" do
        items[#items+1] = item
    end
    return {
        platform = items[1],
        renderer = items[2],
        homogeneous_depth = items[3]:match "1" ~= nil,
        origin_bottom_left = items[4]:match "1" ~= nil,
    }
end

return util