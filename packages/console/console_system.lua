local ecs = ...
local world = ecs.world

local m = ecs.system "console_system"

local eventConsoleReq = world:sub {"editor-req","CONSOLE"}
local function response(...)
    world:pub {"editor-res","CONSOLE",...}
end

local bgfxDebug = false
function m:data_changed()
    for _,_,what in eventConsoleReq:unpack() do
        if what == "debug" then
            local bgfx = require "bgfx"
            if not bgfxDebug then
                bgfxDebug = true
                bgfx.set_debug "ST"
                response "Enable."
            else
                bgfxDebug = false
                bgfx.set_debug ""
                response "Disable."
            end
        end
    end
end
