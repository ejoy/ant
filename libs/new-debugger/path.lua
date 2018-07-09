local fs = require 'cppfs'

local path = {}

local default_sep = package.config:sub(1, 1)

local function split(str)
    local r = {}
    str:gsub('[^/\\]+', function (w) r[#r+1] = w end)
    return r
end

function path.normalize(p, sep)
    p = fs.absolute(fs.path(p))
    local stack = {}
    for _, elem in ipairs(split(p:string())) do
        if #elem == 0 then
        elseif elem == '..' and #stack ~= 0 and stack[#stack] ~= '..' then
            stack[#stack] = nil
        elseif elem ~= '.' then
            stack[#stack + 1] = elem
        end
    end
    return table.concat(stack, sep or default_sep)
end


function path.filename(p)
    local paths = split(p)
    return paths[#paths]
end

return path
