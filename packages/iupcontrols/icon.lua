local iup = require "iuplua"

local iupex = require "iupextension"

local icon = {}
icon.__index = icon

icon.small  = 0      --16*16
icon.normal = 1     --32*32
icon.large = 2     --48*48
icon.largest= 3    --256*256

--todo:
--use icon index to cache icon

--return icon,w,h
function icon.get_icon(filepath)
    local icon,w,h = iupex.icon(filepath)
    return icon,w,h
end

--size_str:"small"/"normal"/"large"/"largest"
--return icon,w,h
function icon.get_icon_ex(filepath,size_str)
    size_str = size_str or "normal"
    local icon,w,h = iupex.icon_with_size(filepath,icon[size_str] or normal)
    print(">>>>>>>>>>>>",filepath,icon,w,h)
    return icon,w,h
end

return icon