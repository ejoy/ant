local ecs = ...
local world = ecs.world
local WatcherEvent = require "hub_event"

local profile_cache = ecs.singleton "profile_cache"
function profile_cache.init()
    return {
        list = {}
    }
end

local world_profile_system =  ecs.system "world_profile_system"
world_profile_system.singleton "profile_cache"

local eventSystemBegin = world:sub {"system_begin"}
local eventSystemEnd = world:sub {"system_end"}

function world_profile_system:update()
    for _,sys,what,time_ms in eventSystemBegin:unpack() do
        if sys ~= "world_profile_system" then
            table.insert(self.profile_cache.list,{sys,what,"begin",time_ms})
        end
    end
    
    for _,sys,what,time_ms in eventSystemEnd:unpack() do
        if sys ~= "world_profile_system" then
            table.insert(self.profile_cache.list,{sys,what,"end",time_ms})
        end
    end
end

function world_profile_system:end_frame()
    local hub = world.args.hub
    hub.publish(WatcherEvent.SystemProfile,self.profile_cache.list)
    self.profile_cache.list = {}
end
