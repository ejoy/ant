local imgui = require "imgui"

local map = {}

for name, index in pairs(imgui.enum.Key) do
    if name ~= "COUNT" then
        map[index] = name
    end
end

return map
