local arg = ...
local manager = require "ltask.manager"

manager.register "arguments"

local S = {}

function S.QUERY()
    return arg
end

return S
