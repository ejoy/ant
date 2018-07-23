local require = import and import(...) or require
local rawtable = require "rawtable"

return function(filename)
    local t = rawtable(filename)
    local files = assert(t.modules)
    local modules = {}
    for _, v in ipairs(files) do

        if package.app_dir then
            local ios_path = package.app_dir .. "/" .. v
            table.insert(modules, assert(loadfile(ios_path)))
        else
            table.insert(modules, assert(loadfile(v)))
        end
    end

    return modules
end