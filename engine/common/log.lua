local ltask = require "ltask"
local LOG
if not debug.getregistry().LTASK_ID then
    --TODO
    function LOG(...)
        io.write(...)
        io.write "\n"
    end
else
    function LOG(...)
        ltask.pushlog(ltask.pack(...))
    end
end

local modes = {
    'info',
    'warn',
    'error'
}
local levels = {}

local function round(x, increment)
    increment = increment or 1
    x = x / increment
    return (x > 0 and math.floor(x + 0.5) or math.ceil(x - 0.5)) * increment
end

local function packstring(...)
    local t = {}
    for i = 1, select('#', ...) do
        local x = select(i, ...)
        if math.type(x) == 'float' then
            x = round(x, 0.01)
        end
        t[#t + 1] = tostring(x)
    end
    return table.concat(t, '\t')
end

local m = {}
m.level = 'info'
m.skip = nil
for i, name in ipairs(modes) do
    levels[name] = i
    m[name] = function(...)
        if i < levels[m.level] then
            return
        end
        local info = debug.getinfo(m.skip or 2, 'Sl')
        m.skip = nil
        LOG(('[%-5s](%s:%3d) %s'):format(name:upper(), info.short_src, info.currentline, packstring(...)))
    end
end

log = m
print = log.info

return m
