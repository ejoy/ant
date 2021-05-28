local repopath = ...
local ltask = require "ltask"
local manager = require "ltask.manager"
local ServiceLogManager = manager.query "log.manager"
local INDEX, LOGFILE = ltask.call(ServiceLogManager, "CREATE", repopath)
local ServiceEditor = manager.query "editor"

local S = {}

function S.LOG(data)
	ltask.send(ServiceEditor, "MESSAGE", "LOG", "RUNTIME", data)
    local fp = assert(io.open(LOGFILE, 'a'))
    fp:write(data)
    fp:write('\n')
    fp:close()
end

function S.QUIT()
    ltask.call(ServiceLogManager, "CLOSE", INDEX)
    ltask.quit()
end

return S
