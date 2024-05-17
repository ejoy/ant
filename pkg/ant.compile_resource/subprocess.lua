local ltask = require "ltask"
local ServiceSubprocess = ltask.uniqueservice "ant.engine|subprocess"

local function quote_arg(s)
    if #s == 0 then
        return '""'
    end
    if not s:find('[ \t\"]', 1) then
        return s
    end
    if not s:find('[\"\\]', 1) then
        return '"' .. s .. '"'
    end
    local quote_hit = true
    local t = {}
    t[#t + 1] = '"'
    for i = #s, 1, -1 do
        local c = s:sub(i, i)
        t[#t + 1] = c
        if quote_hit and c == '\\' then
            t[#t + 1] = '\\'
        elseif c == '"' then
            quote_hit = true
            t[#t + 1] = '\\'
        else
            quote_hit = false
        end
    end
    t[#t + 1] = '"'
    for i = 1, #t // 2 do
        local tmp = t[i]
        t[i] = t[#t - i + 1]
        t[#t - i + 1] = tmp
    end
    return table.concat(t)
end

local function normalize_value(cmds, quote_cmds, v)
    local t = type(v)
    if t == "table" then
        for i = 1, #v do
            normalize_value(cmds, quote_cmds, v[i])
        end
    else
        if t ~= "string" then
            v = tostring(v)
        end
        cmds[#cmds + 1] = v
        quote_cmds[#quote_cmds + 1] = quote_arg(v)
    end
end

local function normalize(commands)
    local cmds = {}
    local quote_cmds = {}
    for i = 1, #commands do
        normalize_value(cmds, quote_cmds, commands[i])
        commands[i] = nil
    end
    commands[1] = cmds
    return table.concat(quote_cmds, " ")
end

local m = {}

function m.spawn(commands)
    local cmdstring = normalize(commands)
    print(cmdstring)
    commands.stdout       = true
    commands.stderr       = "stdout"
    commands.hideWindow   = true
    local errcode, outmsg = ltask.call(ServiceSubprocess, "spawn", commands)
    local ok              = false
    local msg             = {}
    msg[#msg + 1]         = "----------------------------"
    if errcode == 0 then
        msg[#msg + 1] = "Success"
        ok = true
    elseif errcode ~= nil then
        msg[#msg + 1] = string.format("Failed, error code:%x", errcode)
    else
        msg[#msg + 1] = "Failed"
    end
    msg[#msg + 1] = "----------------------------"
    msg[#msg + 1] = cmdstring
    msg[#msg + 1] = "----------------------------"
    msg[#msg + 1] = outmsg
    msg[#msg + 1] = "----------------------------"
    return ok, table.concat(msg, "\n"), outmsg
end

return m
