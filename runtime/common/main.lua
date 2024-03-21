local function LoadFile(path, env)
    local fastio = require "fastio"
    local data = fastio.readall_v(path, path)
    local func, err = fastio.loadlua(data, path, env)
    if not func then
        error(err)
    end
    return func
end

local function LoadDbg(expr)
    local env = setmetatable({}, {__index = _G})
    function env.dofile(path)
        return LoadFile(path, env)()
    end
    assert(load(expr, "=(expr)", "t", env))()
end

local i = 1
while true do
    if arg[i] == '-E' then
    elseif arg[i] == '-e' then
        i = i + 1
        assert(arg[i], "'-e' needs argument")
        LoadDbg(arg[i])
    else
        break
    end
    i = i + 1
end

if arg[i] == nil then
    return
end

for j = -1, #arg do
    arg[j - i] = arg[j]
end
for j = #arg - i + 1, #arg do
    arg[j] = nil
end

dofile "/engine/console/bootstrap.lua"
