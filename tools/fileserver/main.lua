package.path = "engine/?.lua"
require "bootstrap"

local lfs = require "filesystem.local"
local srv = import_package "ant.server"

local logfile
local event = {}

local function luaexe()
    local i = -1
    while arg[i] ~= nil do i = i - 1 end
    return arg[i + 1]
end

srv.init_server {
    lua = luaexe(),
}
srv.set_repopath(arg[1])
srv.listen("0.0.0.0", 2018)
srv.init_proxy()

local _origin = os.time() - os.clock()
local function os_date(fmt)
    local ti, tf = math.modf(_origin + os.clock())
    return os.date(fmt, ti):gsub('{ms}', ('%03d'):format(math.floor(tf*1000)))
end

function event.RUNTIME_CREATE(repo)
    local logdir = repo._root / '.log'
    lfs.create_directories(logdir)
    for path in logdir:list_directory() do
        if path:equal_extension ".log" then
            lfs.create_directories(logdir / 'backup')
            lfs.rename(path, logdir / 'backup' / path:filename())
        end
    end
    logfile = logdir / ('%s.log'):format(os_date('%Y_%m_%d_%H_%M_%S_{ms}'))
end

function event.RUNTIME_CLOSE(repo)
end

function event.SERVER_LOG(...)
    print(...)
end

function event.RUNTIME_LOG(data)
    local fp = assert(lfs.open(logfile, 'a'))
    fp:write(data)
    fp:write('\n')
    fp:close()
end

local function update_event()
    if #srv.event > 0 then
        for i, v in ipairs(srv.event) do
            srv.event[i] = nil
            local f = event[v[1]]
            if f then
                f(table.unpack(v, 2))
            end
        end
    end
end

while true do
    srv.update_network()
    srv.update_server()
    srv.update_proxy()
    update_event()
end
