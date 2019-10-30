local modes = {
    'trace',
    'debug',
    'info',
    'warn',
    'error',
    'fatal',
}
local levels = {}

local origin = os.time() - os.clock()
local function os_date(fmt)
    local ti, tf = math.modf(origin + os.clock())
    return os.date(fmt, ti):gsub('{ms}', ('%03d'):format(math.floor(tf*1000)))
end

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



local function fork()
    local m = {}
    m.level = 'trace'
    m.skip = nil
    for i, name in ipairs(modes) do
        levels[name] = i
        m[name] = function(...)
            if i < levels[m.level] then
                return
            end
            local info = debug.getinfo(m.skip or 2, 'Sl')
            m.skip = nil
            local data = ('[%s][%-5s](%s:%3d) %s'):format(os_date('%Y-%m-%d %H:%M:%S:{ms}'), name:upper(), info.short_src, info.currentline, packstring(...))
            m.raw(data)
        end
    end
    return m
end

local m = fork()

m.fork = fork

return m
