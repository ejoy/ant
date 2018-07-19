local json = require 'cjson'
local cdebug = require 'debugger.backend'

local workerThreads = cdebug.start 'master'

local mgr = {}
local io
local seq = 0
local state = 'birth'

function mgr.newSeq()
    seq = seq + 1
    return seq
end

function mgr.add_io(io_)
    io = io_
end

function mgr.sendToClient(pkg)
    io.send(pkg)
end

function mgr.sendToWorker(w, pkg)
    return workerThreads:send(w, assert(json.encode(pkg)))
end

function mgr.broadcastToWorker(pkg)
    local msg = assert(json.encode(pkg))
    for w in workerThreads:foreach() do
        workerThreads:send(w, msg)
    end
end

function mgr.threads()
    local t = {}
    for w in workerThreads:foreach() do
        t[#t + 1] = w
    end
    return t
end

function mgr.hasThread(w)
    return workerThreads:exists(w)
end

function mgr.update()
    local threads = require 'new-debugger.backend.master.threads'
    for w in workerThreads:foreach() do
        while true do
            local msg = workerThreads:recv(w)
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

function mgr.isState(s)
    return state == s
end

function mgr.setState(s)
    state = s
end

function mgr.close()
    io.close()
    seq = 0
    state = 'birth'
end

return mgr
