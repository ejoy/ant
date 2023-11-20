local ltask = require "ltask"

local LEVELS <const> = {
    'debug',
    'info',
    'warn',
    'error'
}

local LOG = {}

if not debug.getregistry().LTASK_ID then
    --TODO
    for _, level in ipairs(LEVELS) do
        LOG[level] = function (...)
            local t = table.pack(...)
            local str = {}
            for i = 1, t.n do
                str[#str+1] = tostring(t[i])
            end
            local message = table.concat(str, "\t")
            io.write(string.format("[%-5s]", level:upper()))
            io.write(message)
            io.write "\n"
        end
    end
else
    for _, level in ipairs(LEVELS) do
        LOG[level] = function (...)
            local t = table.pack(...)
            local str = {}
            for i = 1, t.n do
                str[#str+1] = tostring(t[i])
            end
            local message = table.concat(str, "\t")
            ltask.pushlog(ltask.pack(level, message))
        end
    end
end

local color = {
    debug = nil,
    info = nil,
    warn = "\x1b[33m",
    error = "\x1b[31m",
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
m.level = __ANT_RUNTIME__ and 'debug' or 'info'
m.skip = nil
for i, level in ipairs(LEVELS) do
    levels[level] = i
    m[level] = function(...)
        if i < levels[m.level] then
            return
        end
        local info = debug.getinfo(m.skip or 2, 'Sl')
        m.skip = nil
        local text = ('(%s:%d) %s'):format(info.short_src, info.currentline, packstring(...))
        if not __ANT_RUNTIME__ and color[level] then
            text = color[level]..text.."\x1b[0m"
        end
        LOG[level](text)
    end
end

---@diagnostic disable-next-line: lowercase-global
log = m
print = log.info

return m
