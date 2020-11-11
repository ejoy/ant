local fs = require "filesystem"

local m = {}

local directorys  = {}

function m.add(dir)
    directorys[#directorys+1] = fs.path(dir)
end

function m.realpath(path)
    for i = #directorys, 1, -1 do
        local file = directorys[i] / path
        if fs.exists(file) then
            return file:localpath():string()
        end
    end
end

return m
