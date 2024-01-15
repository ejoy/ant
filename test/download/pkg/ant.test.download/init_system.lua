local ecs = ...

local m = ecs.system "init_system"

local dl = require "download"
local session = dl.session "ephemeral"

local downloadTask = {}

local function startDownload(url, file)
    local id = dl.download(session, url, file)
    downloadTask[id] = { url = url, file = file }
end

function m:init()
    startDownload(
        "https://antengine-server-patch.ejoy.com/cc/",
        "./test/download/test.html"
    )
end

function m:data_changed()
    for _, msg in ipairs(dl.select(session)) do
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
