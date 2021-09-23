local ecs = ...

local m = ecs.system "debug_system"

local dbg = debug.getregistry()["lua-debug"]

if dbg then
    function m:init()
        dbg:event("autoUpdate", false)
    end
    function m:update_world()
        dbg:event "update"
    end
else
    function m:init()
    end
    function m:update_world()
    end
end
