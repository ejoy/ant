local subprocess = require "bee.subprocess"
local socket = require "bee.socket"
local select = require "bee.select"
local selector = select.create()
local SELECT_READ <const> = select.SELECT_READ
local SELECT_WRITE <const> = select.SELECT_WRITE
local protocol = require "protocol"
local lfs = require "bee.filesystem"
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
        if path:extension() == ".log" then
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
    local fp = assert(io.open(logfile:string(), 'a'))
    fp:write(data)
    fp:write('\n')
    fp:close()
    sender:push({"RUNTIME", data})
end

function event.RUNTIME_CONSOLE(...)
    sender:push({"CONSOLE", ...})
end

-- local function update_event()
--     if #srv.event > 0 then
--         for i, v in ipairs(srv.event) do
--             srv.event[i] = nil
--             local f = event[v[1]]
--             if f then
--                 f(table.unpack(v, 2))
--             end
--         end
--     end
-- end

local luaexe
local repopath
local function spawnFileServer()
    return subprocess.spawn {
        luaexe,
        (luaexe:sub(-7) == "lua.exe" or luaexe:sub(-3) == "lua") and "tools/fileserver/main.lua" or "3rd/ant/tools/fileserver/main.lua",
        repopath,
        console = "disable",
    }
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
    local fd = assert(socket.create "tcp")
    selector:event_add(fd, SELECT_WRITE)
    assert(fd:connect("127.0.0.1", 2019) ~= nil)
    for f, ev in selector:wait() do
        if fd:status() then
            return fd
        end
    end
end

function m.handle_event()
    local reading_queue = {}
    local output = {}
    for fd, ev in selector:wait(1) do
        if ev & SELECT_READ ~= 0 then
            local reading = fd:recv()
            if reading == nil then
                selector:event_del(fd)
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
end

function m.init(lua_path, repo_path)
    luaexe, repopath = lua_path, repo_path
    local fd = connectFileServer()
    if not fd then
        m.subprocess = spawnFileServer()
        assert(m.subprocess)
        fd = connectFileServer()
        print("connect editor fileserver")
    else
        print("connect external fileserver")
    end
    selector:event_mod(fd, SELECT_READ)
    m.fd = fd
end

return m