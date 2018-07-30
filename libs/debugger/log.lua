local log = { }

log.file = nil
log.level = 'trace'

local modes = {
    'trace',
    'debug',
    'info',
    'warn',
    'error',
    'fatal',
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
    return table.concat(t, ' ')
end

for i, name in ipairs(modes) do
    levels[name] = i
    log[name] = function(...)
        if i < levels[log.level] then
            return
        end
        if not log.file then
            return
        end
        local info = debug.getinfo(2, 'Sl')
        local msg = packstring(...)
        local msg = ('[%s][%s:%3d][%-6s] %s\n'):format(os.date('%Y-%m-%d %H:%M:%S'), info.short_src, info.currentline, name:upper(), msg)
        local fp = assert(io.open(log.file, 'a'))
        fp:write(msg)
        fp:close()
    end
end

return log
