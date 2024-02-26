local platform  = require "bee.platform"
local DEBUG = platform.DEBUG
    and platform.os ~= "ios"
    and platform.os ~= "android"
if DEBUG then
    local ecs_core = require "ecs.core"
    ecs_core.DEBUG = true
end
local ecs = require "ecs"

ecs.exporter = require "exporter"

return ecs
