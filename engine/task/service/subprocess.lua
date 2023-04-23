local ltask = require "ltask"
local exclusive = require "ltask.exclusive"
local subprocess = require "bee.subprocess"

local S = {}

local progs = {}

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
    return ltask.wait(prog)
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
            i = i + 1
        else
            table.remove(progs, i)
            local errmsg = prog.stdout:read "a"
            local errcode = prog:wait()
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
