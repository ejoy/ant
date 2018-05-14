local ecs = ...
local world = ecs.world

local editor_mainwin = require "editor.window"

local editor_sys = ecs.system "editor_system"
editor_sys.singleton "math_stack"
editor_sys.depend "end_frame"

function editor_sys:init()
    local hv = editor_mainwin.hierarchyview
    hv:build(world)
end