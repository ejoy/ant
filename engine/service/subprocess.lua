local ltask = require "ltask"
local exclusive = require "ltask.exclusive"
local subprocess = require "bee.subprocess"

local S = {}

local progs = {}
local output = {}

local MaxSubprocess <const> = 8
local WaitQueue = {}

function S.run(command)
    while #progs > MaxSubprocess do
        WaitQueue[#WaitQueue+1] = command
        ltask.wait(command)
    end
    local prog, err = subprocess.spawn(command)
    if not prog then
        return nil, err
    end
    progs[#progs+1] = prog
    return ltask.wait(prog)
end

local function update_output(prog)
    if not prog.stdout then
        return
    end
    local n = subprocess.peek(prog.stdout)
    if n and n > 0 then
        local data = prog.stdout:read(n)
        local t = output[prog]
        if t then
            t[#t+1] = data
        else
            output[prog] = {data}
        end
    end
end

local function finish_output(prog)
    if not prog.stdout then
        return ""
    end
    local data = prog.stdout:read "a"
    local t = output[prog]
    if not t then
        return data
    end
    output[prog] = nil
    t[#t+1] = data
    return table.concat(t)
end

local function update()
    local ok = subprocess.select(progs, 100)
    if not ok then
        return
    end
    local i = 1
    while i <= #progs do
        local prog = progs[i]
        if prog:is_running() then
            update_output(prog)
            i = i + 1
        else
            table.remove(progs, i)
            local errmsg = finish_output(prog)
            local errcode = prog:wait()
            prog:detach()
            ltask.wakeup(prog, errcode, errmsg)
        end
    end
    if #WaitQueue > 0 and #progs < MaxSubprocess then
        local n = math.min(MaxSubprocess-#progs, #WaitQueue)
        for _ = 1, n do
            ltask.wakeup(table.remove(WaitQueue, 1))
        end
    end
end

ltask.fork(function()
    while true do
        ltask.sleep(0)
        if #progs == 0 then
            exclusive.sleep(100)
        else
            update()
        end
    end
end)

return S
