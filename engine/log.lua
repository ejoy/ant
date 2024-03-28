local ltask = require "ltask"

local LEVELS <const> = {
    'debug',
    'info',
    'warn',
    'error'
}

local COLOR <const> = {
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

local label = ltask.label()

local m = {}
m.level = __ANT_RUNTIME__ and 'debug' or 'info'
for i, level in ipairs(LEVELS) do
    levels[level] = i
    m[level] = function (...)
        if i < levels[m.level] then
            return
        end
        local info = debug.getinfo(2, 'Sl')
        local message = ('( %s )(%s:%d) %s'):format(label, info.short_src, info.currentline, packstring(...))
        if not __ANT_RUNTIME__ and COLOR[level] then
            message = COLOR[level]..message.."\x1b[0m"
        end
        ltask.pushlog(ltask.pack(level, message))
    end
end

---@diagnostic disable-next-line: lowercase-global
log = m
print = log.info

return m
