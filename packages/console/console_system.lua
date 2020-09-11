local ecs = ...
local world = ecs.world

local m = ecs.system "msg_system"

local eventConsoleReq = world:sub {"editor-req","console"}
local function response(...)
    world:sub {"editor-res","console",...}
end

local bgfxDebug = false
function m:data_changed()
    for _,_,what in eventConsoleReq:unpack() do
        if what == "debug" then
            local bgfx = require "bgfx"
            if bgfxDebug then
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
