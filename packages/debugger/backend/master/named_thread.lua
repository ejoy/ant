local thread = require "remotedebug.thread"

local exitGuard = {}

local threadMgr = [[
    local thread = require "remotedebug.thread"
    local MgrChanReq = thread.channel "NamedThread-Req:%s"
    local function MgrUpdate()
        while true do
            local ok, msg, id = MgrChanReq:pop()
            if not ok then
                return
            end
            if msg == "EXIT" then
                local res = thread.channel("NamedThread-Res:"..id)
                res:push "BYE"
            end
        end
    end
]]

local function reqChannelName(name)
    return "NamedThread-Req:"..name
end

local function resChannelName()
    return "NamedThread-Res:"..thread.id
end

local function createChannel(name)
    local ok, err = pcall(thread.newchannel, name)
    if not ok then
        if err:sub(1,17) ~= "Duplicate channel" then
            error(err)
        end
    end
    return not ok
end

local function createThread(name, script)
    if createChannel(reqChannelName(name)) then
        return
    end
    thread.thread(thread.bootstrap_lua .. threadMgr:format(name) .. script, thread.bootstrap_c)
    exitGuard[#exitGuard+1] = name
    local errlog = thread.channel "errlog"
    local ok, msg = errlog:pop()
    if ok then
        print(msg)
    end
end

local function init()
    return not createChannel(resChannelName())
end

local function destoryThread(name)
    local reqChan = thread.channel(reqChannelName(name))
    local resChan = thread.channel(resChannelName())
    reqChan:push("EXIT", thread.id)
    resChan:bpop()
end

setmetatable(exitGuard, {__gc=function(self)
    for i = #self, 1, -1 do
        destoryThread(self[i])
    end
end})

return {
    init = init,
    createChannel = createChannel,
    createThread = createThread,
}
