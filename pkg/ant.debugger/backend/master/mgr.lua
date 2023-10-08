local proto = require 'common.protocol'
local ev = require 'backend.event'
local thread = require 'bee.thread'
local stdio = require 'luadebug.stdio'

local redirect = {}
local mgr = {}
local network
local seq = 0
local initialized = false
local stat = {}
local queue = {}
local masterThread
local client = {}
local maxThreadId = 0
local threadChannel = {}
local threadCatalog = {}
local threadStatus = {}
local threadName = {}
local terminateDebuggeeCallback
local exitMaster = false
local quit = false

local function genThreadId()
    maxThreadId = maxThreadId + 1
    return maxThreadId
end

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
    if not initialized then
        return
    end
    mgr.workerBroadcast {
        cmd = 'terminated',
    }
    ev.emit('close')
    initialized = false
    seq = 0
    stat = {}
    queue = {}
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
    masterThread = thread.channel 'DbgMaster'
    network.event_in(event_in)
    network.event_close(event_close)
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

function mgr.clientSend(pkg)
    if not initialized then
        return
    end
    network.send(proto.send(pkg, stat))
end

function mgr.workerSend(w, msg)
    return threadChannel[w]:push(msg)
end

function mgr.workerBroadcast(msg)
    for _, channel in pairs(threadChannel) do
        channel:push(msg)
    end
end

function mgr.workerBroadcastExclude(exclude, msg)
    for w, channel in pairs(threadChannel) do
        if w ~= exclude then
            channel:push(msg)
        end
    end
end

function mgr.setThreadName(w, name)
    threadName[w] = name
end

function mgr.workers()
    return threadChannel
end

function mgr.threads()
    local t = {}
    for threadId, status in pairs(threadStatus) do
        if status == "connect" then
            t[#t + 1] = {
                name = (threadName[threadId] or "Thread (${id})"):gsub("%$%{([^}]*)%}", {
                    id = threadId
                }),
                id = threadId,
            }
        end
    end
    table.sort(t, function(a, b)
        return a.name < b.name
    end)
    return t
end

function mgr.hasThread(w)
    return threadChannel[w] ~= nil
end

function mgr.initWorker(WorkerIdent)
    local workerChannel = ('DbgWorker(%s)'):format(WorkerIdent)
    local threadId = genThreadId()
    threadChannel[threadId] = assert(thread.channel(workerChannel))
    threadCatalog[WorkerIdent] = threadId
    threadStatus[threadId] = "disconnect"
    threadName[threadId] = nil
    ev.emit('worker-ready', threadId)
end

function mgr.setThreadStatus(threadId, status)
    threadStatus[threadId] = status
    if terminateDebuggeeCallback and status == "disconnect" then
        for _, s in pairs(threadStatus) do
            if s == "connect" then
                return
            end
        end
        terminateDebuggeeCallback()
    end
end

function mgr.setTerminateDebuggeeCallback(callback)
    for _, s in pairs(threadStatus) do
        if s == "connect" then
            terminateDebuggeeCallback = callback
            return
        end
    end
    callback()
end

function mgr.exitWorker(w)
    threadChannel[w] = nil
    for WorkerIdent, threadId in pairs(threadCatalog) do
        if threadId == w then
            threadCatalog[WorkerIdent] = nil
        end
    end
    threadStatus[w] = nil
    threadName[w] = nil
    if exitMaster then
        if next(threadChannel) == nil then
            quit = true
        end
    end
end

local function update_redirect()
    if redirect.stderr then
        local res = redirect.stderr:read(redirect.stderr:peek())
        if res then
            local event = require 'backend.master.event'
            event.output {
                category = 'stderr',
                output = res,
            }
        end
    end
    if redirect.stdout then
        local res = redirect.stdout:read(redirect.stdout:peek())
        if res then
            local event = require 'backend.master.event'
            event.output {
                category = 'stdout',
                output = res,
            }
        end
    end
end

local function update_once()
    local threadCMD = require 'backend.master.threads'
    while true do
        local ok, w, cmd, msg = masterThread:pop()
        if not ok then
            break
        end
        if cmd == "EXIT" then
            update_redirect()
            exitMaster = true
            if next(threadChannel) == nil then
                quit = true
            end
            return
        end
        if threadCMD[cmd] then
            threadCMD[cmd](threadCatalog[w] or w, msg)
        end
    end
    update_redirect()
    if not network.update() then
        return true
    end
    local req = recv()
    if not req then
        return true
    end
    if req.type == 'request' then
        -- TODO
        local request = require 'backend.master.request'
        if not initialized then
            if req.command == 'initialize' then
                initialized = true
                request.initialize(req)
            else
                local response = require 'backend.master.response'
                response.error(req, ("`%s` not yet implemented.(birth)"):format(req.command))
            end
        else
            local f = request[req.command]
            if f and req.command ~= 'initialize' then
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
    while not quit do
        if update_once() then
            thread.sleep(0.01)
        end
    end
    local event = require 'backend.master.event'
    event.terminated()
    network.closeall()
end

function mgr.setClient(c)
    client = c
end

function mgr.getClient()
    return client
end

return mgr
