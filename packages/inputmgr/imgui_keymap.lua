local imgui = require "imgui"

local OFFSET <const> = 512
local map = {}

for name, index in pairs(imgui.enum.Key) do
    if name ~= "COUNT" then
        map[index+1-OFFSET] = name
    end
end

return map
