local json = require 'common.json'
local proto = require 'common.protocol'
local ev = require 'common.event'
local thread = require 'common.thread'
local stdio = require 'remotedebug.stdio'

local redirect = {}
local mgr = {}
local network
local seq = 0
local state = 'birth'
local stat = {}
local queue = {}
local exit = false
local masterThread
local workers = {}

ev.on('thread', function(reason, threadId)
    if reason == "started" then
        workers[threadId] = assert(thread.channel_produce("DbgWorker" .. threadId))
        ev.emit('worker-ready', threadId)
    elseif reason == "exited" then
        workers[threadId] = nil
    end
end)

local function event_in(data)
    local msg = proto.recv(data, stat)
    if msg then
        queue[#queue + 1] = msg
        while msg do
            msg = proto.recv('', stat)
            if msg then
                queue[#queue + 1] = msg
            end
        end
    end
end

local function event_close()
    mgr.close()
end

local function recv()
    if #queue == 0 then
        return
    end
    return table.remove(queue, 1)
end

function mgr.newSeq()
    seq = seq + 1
    return seq
end

function mgr.init(io)
    network = io
    masterThread = thread.channel_consume 'DbgMaster'
    network:event_in(event_in)
    network:event_close(event_close)
    return true
end

local function lst2map(t)
    local r = {}
    for _, v in ipairs(t) do
        r[v] = true
    end
    return r
end

function mgr.initConfig(config)
    if redirect.stdout then
        redirect.stdout:close()
        redirect.stdout = nil
    end
    if redirect.stderr then
        redirect.stderr:close()
        redirect.stderr = nil
    end
    local outputCapture = lst2map(config.initialize.outputCapture)
    if outputCapture.stdout then
        redirect.stdout = stdio.redirect 'stdout'
    end
    if outputCapture.stderr then
        redirect.stderr = stdio.redirect 'stderr'
    end
end

function mgr.sendToClient(pkg)
    network:send(proto.send(pkg, stat))
end

function mgr.sendToWorker(w, pkg)
    return workers[w]:push(assert(json.encode(pkg)))
end

function mgr.broadcastToWorker(pkg)
    local msg = assert(json.encode(pkg))
    for _, channel in pairs(workers) do
        channel:push(msg)
    end
end

function mgr.threads()
    local t = {}
    for w in pairs(workers) do
        t[#t + 1] = w
    end
    return t
end

function mgr.hasThread(w)
    return rawget(workers, w) ~= nil
end

local function updateOnce()
    local threads = require 'backend.master.threads'
    while true do
        local ok, w, msg = masterThread:pop()
        if not ok then
            break
        end
        local _ = workers[w]
        local pkg = assert(json.decode(msg))
        if threads[pkg.cmd] then
            threads[pkg.cmd](w, pkg)
        end
    end
    if redirect.stderr then
        local res = redirect.stderr:read(redirect.stderr:peek())
        if res then
            local event = require 'backend.master.event'
            event.output('stderr', res)
        end
    end
    if redirect.stdout then
        local res = redirect.stdout:read(redirect.stdout:peek())
        if res then
            local event = require 'backend.master.event'
            event.output('stdout', res)
        end
    end

    if mgr.isState 'terminated' then
        mgr.setState 'birth'
        return false
    end
    if not network:update() then
        return true
    end
    local req = recv()
    if not req then
        return true
    end
    if req.type == 'request' then
        -- TODO
        local request = require 'backend.master.request'
        if mgr.isState 'birth' then
            if req.command == 'initialize' then
                request.initialize(req)
            else
                local response = require 'backend.master.response'
                response.error(req, ("`%s` not yet implemented.(birth)"):format(req.command))
            end
        else
            local f = request[req.command]
            if f then
                if f(req) then
                    return true
                end
            else
                local response = require 'backend.master.response'
                response.error(req, ("`%s` not yet implemented.(idle)"):format(req.command))
            end
        end
    end
    return false
end

function mgr.update()
    while true do
        if updateOnce() then
            return
        end
    end
end

function mgr.isState(s)
    return state == s
end

function mgr.setState(s)
    state = s
end

function mgr.termOnExit(v)
    exit = v
end

function mgr.close()
    if state == 'birth' then
        return
    end
    mgr.broadcastToWorker {
        cmd = 'terminated',
    }
    ev.emit('close')
    mgr.setState 'terminated'
    seq = 0
    state = 'birth'
    stat = {}
    queue = {}
    network:close()
    if exit then
        os.exit(true, true)
    end
end

return mgr
