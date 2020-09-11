local lfs = require "filesystem.local"
local srv = import_package "ant.server"
local cthread = require "thread"
local sender

local m = {}

local logfile
local event = {}
local repo_instance
local _origin = os.time() - os.clock()
local function os_date(fmt)
    local ti, tf = math.modf(_origin + os.clock())
    return os.date(fmt, ti):gsub('{ms}', ('%03d'):format(math.floor(tf*1000)))
end

function event.RUNTIME_CREATE(repo)
    repo_instance = repo
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
    sender:push({...})
end

function event.RUNTIME_LOG(data)
    -- local fp = assert(lfs.open(logfile, 'a'))
    -- fp:write(data)
    -- fp:write('\n')
    -- fp:close()
    sender:push({data})
end

function event.RUNTIME_CONSOLE(...)
    sender:push({"CONSOLE", ...})
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

local arg
local repopath
local function luaexe()
    local i = -1
    while arg[i] ~= nil do i = i - 1 end
    return arg[i + 1]
end

function m.run()
    srv.init_server {
        lua = luaexe(),
    }
    srv.set_repopath(repopath)
    srv.listen("0.0.0.0", 2018)
    srv.init_proxy()
    local console_receiver = cthread.channel_consume "console_channel"
    while true do
        srv.update_network()
        srv.update_server()
        srv.update_proxy()
        update_event()
        local has, command = console_receiver:pop()
        if has and repo_instance then
            srv.console(repo_instance, command)
        end
    end
end

return function()
    arg, repopath = cthread.channel_consume "fileserver_channel"()
    sender = cthread.channel_produce "log_channel"
    return m
end
