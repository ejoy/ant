local ecs = ...

local m = ecs.system "init_system"

local httpc = require "httpc"
local session = httpc.session "ephemeral"

local Tasks = {}

local function startDownload(url, file)
    local id = httpc.download(session, url, file)
    Tasks[id] = {
        type = "download",
        url = url,
        file = file,
    }
end

local function startUpload(url, file, name)
    local id = httpc.upload(session, url, file, name, "------------------------x2PwarBSOi76w65iTCDl5Y")
    Tasks[id] = {
        type = "upload",
        url = url,
        file = file,
    }
end

function m:init()
    startDownload(
        "https://ejoy.com/",
        "./test/httpc/download/index.html"
    )
    startDownload(
        "https://ejoy.com/product.html",
        "./test/httpc/download/product.html"
    )
    startDownload(
        "https://ejoy.com/links.html",
        "./test/httpc/download/links.html"
    )
end

function m:data_changed()
    for _, msg in ipairs(httpc.select(session)) do
        if msg.type == "completion" then
            local task = Tasks[msg.id]
            print("`" .. task.url .. "` completion. code="..msg.code..".")
            Tasks[msg.id] = nil
        elseif msg.type == "progress" then
            local task = Tasks[msg.id]
            if msg.total then
                print(("`%s` %d/%d."):format(task.url, msg.n, msg.total))
            else
                print(("`%s` %d."):format(task.url, msg.n))
            end
        elseif msg.type == "response" then
            local task = Tasks[msg.id]
            print(("`%s` response: %s."):format(task.url, msg.data))
        elseif msg.type == "error" then
            local task = Tasks[msg.id]
            print(("`%s` error: %s."):format(task.url, msg.errmsg))
        end
    end
end
