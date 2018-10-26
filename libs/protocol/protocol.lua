-- This module is for ant runtime/editer communication
-- See docs/fileserver.txt

local core = require "protocol.core"

local protocol = {}

-- inputmsg { strings, ... } , output[opt] {}
-- return output { lines, ... }
protocol.readmessage = core.readmessage
protocol.packmessage = core.packmessage

return protocol
