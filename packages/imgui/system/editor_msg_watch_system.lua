local ecs = ...
local world = ecs.world
local WatcherEvent = require "hub_event"
local serialize = import_package 'ant.serialize'
local fs = require "filesystem"
local mathpkg = import_package "ant.math"
local mu = mathpkg.util

local Rx        = import_package "ant.rxlua".Rx

local editor_msg_watch_sys = ecs.system "editor_msg_watch_system"
local sub_msg_tbl = {}
local msgbox_tbl = {}
local hub = world.args.hub

    
local function on_request_get_watch_msg()
    hub.publish(WatcherEvent.RTE.ResponseWatchMsg,msgbox_tbl)
end

local function on_request_modify_watch_msg(new_sub_msg_tbl)
    for i,mb in ipairs(msgbox_tbl) do
        world:unsub(mb)
    end
    msgbox_tbl = {}
    sub_msg_tbl = new_sub_msg_tbl
    for i,msg in ipairs(sub_msg_tbl) do
        msgbox_tbl[i] = world:sub(msg) 
    end
end

function editor_msg_watch_sys:init()
    hub.subscribe(WatcherEvent.ETR.RequestGetWatchMsg,on_request_get_watch_msg)
    hub.subscribe(WatcherEvent.ETR.RequestModifyWatchMsg,on_request_modify_watch_msg)
end

function editor_msg_watch_sys:editor_update()
    for i,mb in  ipairs(msgbox_tbl) do
        for msg in mb:each() do
            log.info_a("[WatchMsg]:",msg)
        end
    end
end