local subprocess = require "bee.subprocess"
local socket = require "bee.socket"
local protocol = require "protocol"
local lfs = require "filesystem.local"
local cthread = require "bee.thread"
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
    for path in lfs.pairs(logdir) do
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
    sender:push({"SERVER", ...})
end

function event.RUNTIME_LOG(_, data)
    local fp = assert(lfs.open(logfile, 'a'))
    fp:write(data)
    fp:write('\n')
    fp:close()
    sender:push({"RUNTIME", data})
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
    return "./bin/msvc/release/lua.exe"
end

local function spawnFileServer()
    assert(subprocess.spawn {
        luaexe(),
        "tools/fileserver/main.lua",
        repopath,
        console = "disable",
    })
end

local message = {}

function message.LOG(type, data)
    if type == "SERVER" then
        sender:push({"SERVER", data})
    elseif type == "RUNTIME" then
        sender:push({"RUNTIME", data})
    end
end

local function connectFileServer()
    local fd = assert(socket "tcp")
    assert(fd:connect("127.0.0.1", 2019) ~= nil)
    local _, wr = socket.select(nil, {fd})
    if wr and wr[1] == fd and fd:status() then
        return fd
    end
end

local function handleNetworkEvent(fd)
    local reading_queue = {}
    local output = {}
    while true do
        if not socket.select({fd}) then
            fd:close()
            break
        end
        local reading = fd:recv()
        if reading == nil then
            fd:close()
            break
        elseif reading == false then
        else
            table.insert(reading_queue, reading)
            while true do
                local msg = protocol.readmessage(reading_queue, output)
                if msg == nil then
                    break
                end
                local f = message[msg[1]]
                if f then
                    f(table.unpack(msg, 2))
                else
                    error(msg[1])
                end
            end
        end
    end
end

function m.run()
    local fd = connectFileServer()
    if not fd then
        spawnFileServer()
        fd = connectFileServer()
        print("connect editor file server")
    else
        print("connect external file server")
    end
    
    handleNetworkEvent(fd)

    --srv.init_server {
    --    lua = luaexe(),
    --}
    --srv.set_repopath(repopath)
    --srv.listen("0.0.0.0", 2018)
    --srv.init_proxy()
    --local console_receiver = cthread.channel_consume "console_channel"
    --while true do
    --    srv.update_network()
    --    srv.update_server()
    --    srv.update_proxy()
    --    update_event()
    --    local has, command = console_receiver:pop()
    --    if has and repo_instance then
    --        srv.console(repo_instance, command)
    --    end
    --end
end

return function()
    arg, repopath = (cthread.channel "fileserver_channel"):bpop()
    sender = cthread.channel "log_channel"
    return m
end
