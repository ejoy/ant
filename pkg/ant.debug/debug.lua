local ecs = ...
local world = ecs.world
local w = world.w

local debug_sys = ecs.system "debug_system"

local ig        = ecs.require "ant.group|group"

local tick = 30

local function hitch_cull_test()
    if tick == 30 then
        local groups = {}
        local queuemgr = ecs.require "ant.render|queue_mgr"
        local mainmask = queuemgr.queue_mask "main_queue"
        local group_culled, group_no_culled, group_sum = 0, 0, 0
        for e in w:select "hitch:in" do
            local gid = e.hitch.group
            if not groups[gid] then groups[gid] = {culled = 0, no_culled = 0, hitch_sum = 0, hitch_tag = 0} end
            local gg = groups[gid]
            gg.hitch_sum = gg.hitch_sum + 1
            if 0 ~= (e.hitch.cull_masks & mainmask) then
                gg.culled = gg.culled + 1
            else
                gg.no_culled = gg.no_culled + 1
            end
        end
    
        for gid, gg in pairs(groups) do
            ig.enable(gid, "hitch_tag", true)
            local culled, no_culled, hitch_sum = gg.culled, gg.no_culled, gg.hitch_sum
            for e in w:select "hitch_tag:in render_object:in" do
                gg.hitch_tag = gg.hitch_tag + 1
            end
            group_culled, group_no_culled, group_sum = group_culled + gg.hitch_tag * culled, group_no_culled + gg.hitch_tag * no_culled, group_sum + gg.hitch_tag * hitch_sum
            ig.enable(gid, "hitch_tag", false)
        end
    
        print("hitch object group_culled:", group_culled)
        print("hitch object group_no_culled:", group_no_culled)
        print("hitch object group_sum:", group_sum)
        print("----------------------------------------------------------------------")
        tick = 0
    else
        tick = tick + 1 
    end   
end

function debug_sys:init()
end

function debug_sys:data_changed()
    hitch_cull_test()
end