local json = require 'cjson.safe'
local proto = require 'debugger.protocol'
local ev = require 'debugger.event'
local thread = require 'thread'

local mgr = {}
local network
local seq = 0
local state = 'birth'
local stat = {}
local queue = {}
local exit = false

local workers_mt = {}
function workers_mt:__index(id)
    assert(type(id) == "number")
    local c = assert(thread.channel("DbgWorker" .. id))
    self[id] = c
    return c
end
local workers = setmetatable({}, workers_mt)

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

function mgr.init(io, masterThread_)
    network = io
    masterThread = masterThread_
    network:event_in(event_in)
    network:event_close(event_close)
end

function mgr.sendToClient(pkg)
    network:send(proto.send(pkg))
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

function mgr.update()
    local threads = require 'debugger.backend.master.threads'
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
end

function mgr.runIdle()
    mgr.update()
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
        local request = require 'debugger.backend.master.request'
        if mgr.isState 'birth' then
            if req.command == 'initialize' then
                request.initialize(req)
            else
                local response = require 'debugger.backend.master.response'
                response.error(req, ("`%s` not yet implemented.(birth)"):format(req.command))
            end
        else
            local f = request[req.command]
            if f then
                if f(req) then
                    return true
                end
            else
                local response = require 'debugger.backend.master.response'
                response.error(req, ("`%s` not yet implemented.(idle)"):format(req.command))
            end
        end
    end
    return false
end

function mgr.isState(s)
    return state == s
end

function mgr.setState(s)
    state = s
end

function mgr.exitWhenClose()
    exit = true
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
