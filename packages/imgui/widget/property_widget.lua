local factory = require "widget.base_property_widget"
local other = {
    "widget.quaternion_widget",
}

for i,path in ipairs(other) do
    local other_factory = require(path)
    factory.CombineFactory(other_factory)
end

return factory