log = require "common.log"

local thread = require "thread"
local IO = thread.channel_produce "IOreq"

function log.raw(data)
    IO("SEND", "LOG", data)
end

print = log.info

return log
