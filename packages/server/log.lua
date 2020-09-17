local event = require "event"

-- return function (...)
--     event[#event+1] = {"SERVER_LOG", ...}
-- end
local m = {}
local function add_event(level, tag, ...)
    event[#event+1] = {"SERVER_LOG", os.time(), level, tag, ...}
end
function m.info(tag, ...)
    add_event("info", tag, ...)
end
function m.warn(tag, ...)
    add_event("warn", tag, ...)
end
function m.error(tag, ...)
    add_event("error", tag, ...)
end

return m