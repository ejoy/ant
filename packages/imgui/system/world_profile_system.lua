local ecs = ...
local world = ecs.world
local WatcherEvent = require "hub_event"

local timer = import_package "ant.timer"

local profile_cache = ecs.singleton "profile_cache"
function profile_cache.init()
    self = {}
    self.list = {}
    return self
end

local world_profile_system =  ecs.system "world_profile_system"
world_profile_system.singleton "profile_cache"

function world_profile_system:system_begin()
    local sys,what = world:get_cur_system()
    local time_ms = timer.cur_time()
    if sys ~= "world_profile_system" then
        table.insert(self.profile_cache.list,{sys,what,"begin",time_ms})
    end
end

function world_profile_system:system_end()
    local sys,what = world:get_cur_system()
    local time_ms = timer.cur_time()
    if sys ~= "world_profile_system" then
        table.insert(self.profile_cache.list,{sys,what,"end",time_ms})
    end
end

function world_profile_system:end_frame()
    local hub = world.args.hub
    hub.publish(WatcherEvent.SystemProfile,self.profile_cache.list)
    self.profile_cache.list = {}
end