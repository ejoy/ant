local require = import and import(...) or require
local rawtable = require "rawtable"

return function(filename)
    local t = rawtable(filename)
    local files = assert(t.modules)
    local modules = {}
    for _, v in ipairs(files) do
        --use open(with network function)
        local file = io.open(v, "r")

        if file then
            io.input(file)
            local file_string = file:read("*a")

            print("get module "..v)
            table.insert(modules, assert(load(file_string)))
        end
    end

    return modules
end