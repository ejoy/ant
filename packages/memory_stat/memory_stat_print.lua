local ecs = ...

local memmgr = require "memory_mgr"

local stat_print = ecs.system "memory_stat_print"

function stat_print:update()
    local m = memmgr.bgfx_stat('m')
    for k, v in pairs(m) do
        print(k, v)
    end
end