local ecs = ...
local world = ecs.world
local WatcherEvent = require "hub_event"

ecs.component "profile_cache" {}
ecs.singleton "profile_cache" {}

local world_profile_system =  ecs.system "world_profile_system"
world_profile_system.require_singleton "profile_cache"

local eventSystemHook = world:sub {"system_hook"}

function world_profile_system:editor_update()
    local e = world:singleton_entity "profile_cache"
    local profile_cache = e.profile_cache
    for _,typ,sys,what,stepname,time_ms in eventSystemHook:unpack() do
        if sys ~= "world_profile_system" then
            profile_cache[#profile_cache+1] = {sys,stepname,typ,time_ms}
        end
    end
    local hub = world.args.hub
    hub.publish(WatcherEvent.SystemProfile, profile_cache)
    e.profile_cache = {}
end
