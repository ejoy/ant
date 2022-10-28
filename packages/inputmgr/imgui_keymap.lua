local imgui = require "imgui"

local map = {}

for name, index in pairs(imgui.enum.Key) do
    map[index] = name
end

return map
