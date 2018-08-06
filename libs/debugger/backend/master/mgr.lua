local json = require 'cjson'
local proto = require 'debugger.protocol'

local mgr = {}
local network
local seq = 0
local state = 'birth'
local stat = {}
local queue = {}
local exit = false

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
end

function mgr.sendToClient(pkg)
    network:send(proto.send(pkg))
end

function mgr.sendToWorker(w, pkg)
    return masterThread:send(w, assert(json.encode(pkg)))
end

function mgr.broadcastToWorker(pkg)
    local msg = assert(json.encode(pkg))
    for w in masterThread:foreach() do
        masterThread:send(w, msg)
    end
end

function mgr.threads()
    local t = {}
    for w in masterThread:foreach() do
        t[#t + 1] = w
    end
    return t
end

function mgr.hasThread(w)
    return masterThread:exists(w)
end

function mgr.update()
    local threads = require 'debugger.backend.master.threads'
    for w in masterThread:foreach(true) do
        while true do
            local msg = masterThread:recv(w)
            if not msg then
                break
            end
            local pkg = assert(json.decode(msg))
            if threads[pkg.cmd] then
                threads[pkg.cmd](w, pkg)
            end
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
    network:close()
    seq = 0
    state = 'birth'
    stat = {}
    queue = {}
    if exit then
        os.exit(true, true)
    end
end

return mgr
