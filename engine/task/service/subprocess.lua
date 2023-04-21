local ltask = require "ltask"
local exclusive = require "ltask.exclusive"
local subprocess = require "bee.subprocess"

local S = {}

local progs = {}

function S.run(command)
    local prog, err = subprocess.spawn(command)
    if not prog then
        return nil, err
    end
    progs[#progs + 1] = prog
    return ltask.wait(prog)
end

local function update()
    local ok = subprocess.select(progs)
    assert(ok)
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
