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

local origin = os.time() - os.clock()
local function os_date(fmt)
    local ti, tf = math.modf(origin + os.clock())
    local date = os.date(fmt, ti)
    ---@cast date string
    return date:gsub('{ms}', ('%03d'):format(math.floor(tf*1000)))
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
    return table.concat(t, ' ')
end

local function filename(info)
    local s = info.source
    if log.root and s:sub(1,1) == "@" then
        s = s:gsub("\\", "/")
        if log.root == s:sub(2, 1+#log.root) then
            return s:sub(3+#log.root)
        end
    end
    return info.short_src
end

if log.root then
    log.root = log.root:gsub("\\", "/")
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
        local msg = ('[%s][%s:%3d][%-5s]%s\n'):format(
            os_date('%Y-%m-%d %H:%M:%S:{ms}'),
            filename(info),
            info.currentline,
            name:upper(),
            packstring(...)
        )
        local fp = assert(io.open(log.file, 'a'))
        fp:write(msg)
        fp:close()
    end
end

log.print = print
print = log.info

return log
