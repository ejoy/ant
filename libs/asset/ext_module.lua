local require = import and import(...) or require
local rawtable = require "rawtable"

return function(filename)
    local t = rawtable(filename)
    local files = assert(t.modules)
    local modules = {}
    for _, v in ipairs(files) do
        table.insert(modules, assert(loadfile(v)))
    end

    return modules
end