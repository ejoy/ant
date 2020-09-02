local event = require "event"

return function (...)
    event[#event+1] = {"SERVER_LOG", ...}
end
