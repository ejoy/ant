local ltask = require "ltask"
local platform = require "bee.platform"

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

local SupportColor <const> = platform.os ~= "ios" and platform.os ~= "android" --TODO
local ServiceName <const> = ltask.label()

local function round(x, increment)
    x = x / increment
    return (x > 0 and math.floor(x + 0.5) or math.ceil(x - 0.5)) * increment
end

local function packstring(...)
    local t = table.pack(...)
    for i = 1, t.n do
        local x = t[i]
        if math.type(x) == 'float' then
            x = round(x, 0.01)
        end
        t[i] = tostring(x)
    end
    return table.concat(t, '\t')
end


local m = {}

m.level = 'debug'

local levels = {}

for i, level in ipairs(LEVELS) do
    levels[level] = i
    local fmt = ('( %s )(%%s:%%d) %%s'):format(ServiceName)
    if SupportColor and COLOR[level] then
        fmt = COLOR[level] .. fmt .. '\x1b[0m'
    end
    m[level] = function (...)
        if i < levels[m.level] then
            return
        end
        local info = debug.getinfo(2, 'Sl')
        local message = fmt:format(info.short_src, info.currentline, packstring(...))
        ltask.pushlog(ltask.pack(level, message))
    end
end

---@diagnostic disable-next-line: lowercase-global
log = m
print = log.info

return m
