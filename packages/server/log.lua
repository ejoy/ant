local event = require "event"

-- return function (...)
--     event[#event+1] = {"SERVER_LOG", ...}
-- end
local m = {}
local function add_event(level, tag, msg)
    event[#event+1] = {"SERVER_LOG", level, os.time(), tag, msg}
end
function m.info(tag, msg)
    add_event("info", tag, msg)
end
function m.warn(tag, msg)
    add_event("warn", tag, msg)
end
function m.error(tag, msg)
    add_event("error", tag, msg)
end

return m