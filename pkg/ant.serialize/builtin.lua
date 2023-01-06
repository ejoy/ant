local m = {}

local builtinPath <const> = {}

function m.stringify(v)
    local mt = getmetatable(v)
    if mt == builtinPath then
        return "path", v[1]
    end
end

function m.path(v)
    return setmetatable({v}, builtinPath)
end

return m
