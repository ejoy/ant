local ecs = ...
local world = ecs.world
local WatcherEvent = require "hub_event"

local profile_cache = {}

local m = ecs.interface "profile_cache"
function m.data()
    return profile_cache
end

local world_profile_sys =  ecs.system "world_profile_system"

local eventSystemHook = world:sub {"system_hook"}

function world_profile_sys:editor_update()
    for _,typ,sys,what,stepname,time_ms in eventSystemHook:unpack() do
        if sys ~= "world_profile_system" then
            profile_cache[#profile_cache+1] = {sys,stepname,typ,time_ms}
        end
    end
    local hub = world.args.hub
    hub.publish(WatcherEvent.RTE.SystemProfile, profile_cache)
    profile_cache = {}
end
