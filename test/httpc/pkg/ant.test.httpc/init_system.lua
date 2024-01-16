local ecs = ...

local m = ecs.system "init_system"

local httpc = require "httpc"
local session = httpc.session "ephemeral"

local downloadTask = {}

local function startDownload(url, file)
    local id = httpc.download(session, url, file)
    downloadTask[id] = { url = url, file = file }
end

--http://antengine-client-logcollector.ejoy.com:80/file_upload

function m:init()
    startDownload(
        "https://antengine-server-patch.ejoy.com/cc/",
        "./test/httpc/test.html"
    )
end

function m:data_changed()
    for _, msg in ipairs(httpc.select(session)) do
        if  msg.type == "completion" then
            local task = downloadTask[msg.id]
            print("`" .. task.url .. "` completion.")
            downloadTask[msg.id] = nil
        elseif msg.type == "progress" then
            local task = downloadTask[msg.id]
            if msg.total then
                print(("`%s` %d/%d."):format(task.url, msg.written, msg.total))
            else
                print(("`%s` %d."):format(task.url, msg.written))
            end
        end
    end
end
