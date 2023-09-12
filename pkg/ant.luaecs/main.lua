local platform  = require "bee.platform"
local DEBUG = platform.DEBUG or platform.os ~= "ios"
if DEBUG then
    local ecs_core = require "ecs.core"
    ecs_core.DEBUG = true
end
return require "ecs"
