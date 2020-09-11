local ecs = ...
local world = ecs.world

local thread = require "thread"
thread.newchannel "EditorMessage"

local channel_req = thread.channel_produce "IOreq"
local channel_msg = thread.channel_consume "EditorMessage"
channel_req("SUBSCIBE", "EditorMessage", "MSG")

local eventEditorRes = world:sub {"editor-res"}

local function dispatch_req(ok, _, ...)
    if not ok then
        return
    end
    world:pub {"editor-req", ...}
    return true
end

local function unpack_res(_,...)
    for i = 1, select("#", ...) do
        assert(type(select(i, ...)) == "string")
    end
    return ...
end

local m = ecs.system "msg_system"

function m:data_changed()
    while dispatch_req(channel_msg:pop()) do
    end
    for e in eventEditorRes:each() do
        channel_req("SEND", "MSG", unpack_res(table.unpack(e)))
    end
end
