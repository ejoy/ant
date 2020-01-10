local ecs = ...
local world = ecs.world
local WatcherEvent = require "hub_event"

ecs.component "profile_cache" {}
ecs.singleton "profile_cache" {}

local world_profile_system =  ecs.system "world_profile_system"
world_profile_system.require_singleton "profile_cache"

local eventSystemBegin = world:sub {"system_begin"}
local eventSystemEnd = world:sub {"system_end"}

function world_profile_system:update()
    local e = world:singleton_entity "profile_cache"
    local profile_cache = e.profile_cache
    for _,sys,what,time_ms in eventSystemBegin:unpack() do
        if sys ~= "world_profile_system" then
            profile_cache[#profile_cache+1] = {sys,what,"begin",time_ms}
        end
    end
    
    for _,sys,what,time_ms in eventSystemEnd:unpack() do
        if sys ~= "world_profile_system" then
            profile_cache[#profile_cache+1] = {sys,what,"end",time_ms}
        end
    end
    local hub = world.args.hub
    hub.publish(WatcherEvent.SystemProfile, profile_cache)
    e.profile_cache = {}
end
