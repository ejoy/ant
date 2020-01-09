local ecs = ...
local world = ecs.world
local WatcherEvent = require "hub_event"
local serialize = import_package 'ant.serialize'
local fs = require "filesystem"
local mathpkg = import_package "ant.math"
local mu = mathpkg.util
local ms = mathpkg.stack
local assetmgr = import_package "ant.asset".mgr
local Rx        = import_package "ant.rxlua".Rx

local OperateFunc = require "system.editor_operate_func"

ecs.tag "editor_watching"
ecs.tag "outline_entity"

ecs.component_alias("target_entity","entityid")


local editor_watcher_system = ecs.system "editor_watcher_system"
editor_watcher_system.require_system "editor_operate_gizmo_system"
editor_watcher_system.require_system 'scene_space' 

editor_watcher_system.require_system "before_render_system"
editor_watcher_system.require_singleton "profile_cache"

ecs.component "editor_watcher_cache" {}
ecs.singleton "editor_watcher_cache" {}

editor_watcher_system.require_singleton "editor_watcher_cache"


local function send_hierarchy()
    local temp = {}
    for _,eid in world:each("name") do
        temp[eid] = {name = world[eid].name,children = nil,childnum=0}
    end
    local result = {}
    for eid,node in pairs(temp) do
        local e = world[eid]
        local pid = e.parent
        if not pid and e.transform then
            pid = e.transform.parent
        end
        if pid and temp[pid] then
            local parent = temp[pid]
            parent.children = parent.children or {}
            parent.children[eid] = node
            parent.childnum = parent.childnum + 1
        else
            result[eid] = node
        end
    end
    local hub = world.args.hub
    hub.publish(WatcherEvent.HierarchyChange,result)
    local rxbus = world.args.rxbus
    local subject = rxbus.get_subject(WatcherEvent.HierarchyChange)
    subject:onNext(result)
    return
end

local function compare_values(val1, val2)
    local type1 = type(val1)
    local type2 = type(val2)
    if type1 ~= type2 then
        return false
    end

    -- Check for NaN
    if type1 == "number" and val1 ~= val1 and val2 ~= val2 then
        return true
    end

    if type1 ~= "table" then
        return val1 == val2
    end

    -- check_keys stores all the keys that must be checked in val2
    local check_keys = {}
    for k, _ in pairs(val1) do
        if k ~= 0 then
            check_keys[k] = true
        end
    end

    for k, v in pairs(val2) do
        if k ~= 0 then
            if not check_keys[k] then
                return false
            end

            if not compare_values(val1[k], val2[k]) then
                return false
            end

            check_keys[k] = nil
        end
    end
    for k, _ in pairs(check_keys) do
        -- Not the same if any keys from val1 were not found in val2
        return false
    end
    return true
end
local last_eid = nil
local last_tbl = nil
local timer = import_package "ant.timer"
local profile_cache = nil
local function send_entity(eids,typ)
    local hub = world.args.hub
    local entity_info = {type = typ}
    if eids == nil or (not world[eids[1]]) then
        hub.publish(WatcherEvent.EntityInfo,entity_info)
        last_eid = nil
        last_tbl = nil
        log.info_a("send_entity","nothing")
    else
        local setialize_result = {}
        table.insert(profile_cache.list,{"editor_watcher_system","entity2tbl","begin",timer.cur_time()})
        for i,eid in ipairs(eids) do
            if world[eid] then
                setialize_result[eid] = serialize.entity2tbl(world,eid)
            end
        end
        table.insert(profile_cache.list,{"editor_watcher_system","entity2tbl","end",timer.cur_time()})
        if compare_values(last_eid,eids) then
            table.insert(profile_cache.list,{"editor_watcher_system","compare_values","begin",timer.cur_time()})
            local b = compare_values(last_tbl,setialize_result)
            table.insert(profile_cache.list,{"editor_watcher_system","compare_values","end",timer.cur_time()})
            if b then
                return
            end
        end
        last_eid = eids
        last_tbl = setialize_result
        entity_info.entities = setialize_result
        entity_info.eids = eids
        hub.publish(WatcherEvent.EntityInfo,entity_info)
        log.info_a("send_entity",eids)
    end
end

local function remove_all_outline()
    local old_eids = {}
    for _, id in world:each("outline_entity") do
        table.insert(old_eids,id)
    end

    for _,id in ipairs(old_eids) do
        world:remove_entity(id)
    end
end

local function create_outline(seleid)
    local se = world[seleid]
    if se then
        if not se.hierarchy then
            world:add_component(seleid,"hierarchy",{})
        end
        -- local trans = se.transform
        -- local s, r, t = ms(trans.t, trans.r, trans.s, "TTT")
        local t = mu.identity_transform()
        t.parent = seleid
        local outlineeid = world:create_entity {
            transform = t,
            rendermesh = {},
            material = {
                ref_path = fs.path "/pkg/ant.resources/depiction/materials/outline/scale.material"
            },
            can_render = true,
            outline_entity = true,
            target_entity = seleid,
            -- name = "outline_object"
        }
        local oe = world[outlineeid]
        oe.rendermesh.reskey = se.rendermesh.reskey
        assetmgr.load(se.rendermesh.reskey)
    end
end

local function change_watch_entity(self,eids,focus,is_pick)
    local adds = {}
    local remove_map = {}
    local olds_map = {}
    for _,id in world:each("editor_watching") do
        olds_map[id] = true
    end
    log.info_a(olds_map,olds_map)
    for _,id in ipairs(eids) do
        if olds_map[id] then
            olds_map[id] = nil
        else
            table.insert(adds,id)
        end
    end
    for id,_ in pairs(olds_map) do
        remove_map[id] = true
    end
    log.info_a("remove_map",remove_map)
    --remove tag:editor_watching,show_operate_gizmo
    for id,_ in pairs(remove_map) do
        world:remove_component(id,"editor_watching")
        log.trace(">>remove_component [editor_watching] from:",id)
        if world[id].show_operate_gizmo then
            world:remove_component(id,"show_operate_gizmo")
            log.trace(">>remove_component [show_operate_gizmo] from:",id)
        end
    end
    --remove entity:outline_entity
    local removes = {}
    for _,id in world:each("outline_entity") do
        local target = world[id].target_entity
        if remove_map[target] then
            table.insert(removes,id)
        end
    end
    for _,id in ipairs(removes) do
        world:remove_entity(id)
    end
    --------------------------
    if (not eids) or #eids <= 0 then
        return 
    end
    local last_eid = eids[#eids]
    if focus then
        --todo calc multselect center
        local camerautil = import_package "ant.render".camera
        if not camerautil.focus_obj(world, last_eid) then
            local transform = world[last_eid].transform
            if transform then
                camerautil.focus_point(world,transform.t)
            end
        end
    end
    local need_send = {}
    for _, eid in ipairs( eids ) do
        local target_ent = world[eid]
        if target_ent.serialize then
            if target_ent.can_select then
                create_outline(eid)
            end
            world:add_component(eid,"editor_watching",true)
            if target_ent.transform then
                world:add_component(eid,"show_operate_gizmo",true)
            end
            table.insert(need_send,eid)
        end
    end
    log.info_a("eids",eids,"need_send",need_send)
    world:singleton "editor_watcher_cache".need_send = need_send
    send_entity(need_send,(is_pick and "pick" or "editor"))
end

local function start_watch_entitiy(eid,focus,is_pick)
    
    if false then
        local hub = world.args.hub
        local old_eids = {}
        for _, id in world:each("editor_watching") do
            table.insert(old_eids,id)
        end
        for _,id in ipairs(old_eids) do
            world:remove_component(id,"editor_watching")
            log.trace(">>remove_component [editor_watching] from:",id)
            if world[id].show_operate_gizmo then
                world:remove_component(id,"show_operate_gizmo")
                log.trace(">>remove_component [show_operate_gizmo] from:",id)
            end
        end
        remove_all_outline()
        ------------------------------------------------
        if (not eid) or (not world[eid]) then
            send_entity(nil,( is_pick and "pick" or "editor"))
            return
        end
        if eid and focus then
            local camerautil = import_package "ant.render".camera
            if not camerautil.focus_obj(world, eid) then
                local transform = world[eid].transform
                if transform then
                    camerautil.focus_point(world, transform.t)
                end
            end
        end
        local target_ent = world[eid]
        if target_ent then
            if target_ent.can_select then
                create_outline(eid)
            end
            world:add_component(eid,"editor_watching",true)
            if target_ent.transform then
                world:add_component(eid,"show_operate_gizmo",true)
            end
            log.trace(">>add_component [editor_watching] to:",eid)
            send_entity({eid},( is_pick and "pick" or "editor"))
        end
    end
    return change_watch_entity(self,eid,focus,is_pick)
end

local function on_editor_select_entity(self,eids,focus)
    -- for i,eid in ipairs(eids) do 
    --     if world[eid] and (not world[eid].gizmo_object) then
    --         start_watch_entitiy(eid,focus,false)
    --     end
    -- end
    change_watch_entity(self,eids,focus,false)
end

local function on_pick_entity(eid)
    if eid then
        if world[eid] and (not world[eid].gizmo_object) then
            start_watch_entitiy({eid},false,true)
        end
    else
        start_watch_entitiy(nil,false,true)
    end
end


local function on_component_modified(eid,com_id,key,value)
    log.trace_a("on_component_modified",eid,com_id,key,value)
    if not com_id then
        serialize.watch.set(world,nil,eid,key,value)
        log.trace_a("after_component_modified:",serialize.watch.query(world,nil,eid))
    else
        serialize.watch.set(world,com_id,"",key,value)
        log.trace_a("after_component_modified:",serialize.watch.query(world,com_id,""))
    end
end


local function on_mult_component_modified(eids,com_ids,key,value,is_list)
    log.trace_a("on_mult_component_modified",eids,com_ids,key,value)
    if not com_ids then
        if not is_list then
            for i,eid in ipairs(eids) do
                serialize.watch.set(world,nil,eid,key,value)
                log.trace_a("after_component_modified:",serialize.watch.query(world,nil,eid))
            end
        else
            for i,eid in ipairs(eids) do
                serialize.watch.set(world,nil,eid,key,value[i])
                log.trace_a("after_component_modified:",serialize.watch.query(world,nil,eid))
            end
        end
    else
        if not is_list then
            for i,com_id in ipairs(com_ids) do
                serialize.watch.set(world,com_id,"",key,value)
                log.trace_a("after_component_modified:",serialize.watch.query(world,com_id,""))
            end
        else
            for i,com_id in ipairs(com_ids) do
                serialize.watch.set(world,com_id,"",key,value[i])
                log.trace_a("after_component_modified:",serialize.watch.query(world,com_id,""))
            end
        end
    end
end


local function copy_table(tbl)
    local new_tbl = {}
    for k,v in pairs(tbl) do
        local vtype = type(v)
        if vtype == "table" then
            new_tbl[k] = copy_table(v)
        elseif vtype ~= "function" then
            new_tbl[k] = v
        end
    end
    return new_tbl
end

-- local function publish_world_info()
--     -- local pm = require "antpm"
--     -- local packages = pm.get_registered_list()
--     local schemas = copy_table(world._schema.map)
--     -- local pack = 
--     -- hub.subscribe(WatcherEvent.RESPONSE_WORLD_INFO,)
--     local hub = world.args.hub
--     hub.publish(WatcherEvent.ResponseWorldInfo,{schemas = schemas})
-- end

local function on_entity_operate( self,event,args )
    log.info_a(event,args)
    OperateFunc(self,world,event,args)
end

local function on_request_hierarchy(self)
    send_hierarchy()
end

function editor_watcher_system:init()
    local hub = world.args.hub
    hub.subscribe(WatcherEvent.WatchEntity,on_editor_select_entity,self)
    hub.subscribe(WatcherEvent.ModifyComponent,on_component_modified)
    hub.subscribe(WatcherEvent.ModifyMultComponent,on_mult_component_modified)
    hub.subscribe(WatcherEvent.EntityOperate,on_entity_operate,self)
    hub.subscribe(WatcherEvent.RequestHierarchy,on_request_hierarchy,self)
    profile_cache = world:singleton "profile_cache"
    -- hub.subscribe(WatcherEvent.RequestWorldInfo,publish_world_info)
    -- publish_world_info()
    local rxbus = world.args.rxbus
    local watchentity_ob = rxbus:get_observable(WatcherEvent.WatchEntity)
    watchentity_ob:subscribe(Rx.handler(on_editor_select_entity,self))
end

function editor_watcher_system:pickup()
    local pickupentity = world:singleton_entity "pickup"
    if pickupentity then
        local pickupcomp = pickupentity.pickup
        local eid = pickupcomp.pickup_cache.last_pick
        local hub = world.args.hub
        if eid and world[eid] then
            if not world[eid].gizmo_object then
                hub.publish(WatcherEvent.SceneEntityPick,{eid})
                on_pick_entity(eid)
            end
        else
            hub.publish(WatcherEvent.SceneEntityPick,{})
            on_pick_entity(nil)
        end
    end
end

local timer = import_package "ant.timer"

local entity_delete_mb = world:sub {"entity_removed"}
local entity_create_mb = world:sub {"entity_created"}
local function entity_delete_handle()
    local hierarchy_dirty = false
    for msg in entity_delete_mb:each() do
        local e = msg[3]
        if not e or (e.pickup == nil and e.outline_entity == nil) then
            hierarchy_dirty = true
            break
        end
    end
    if hierarchy_dirty then
        send_hierarchy()
    end
end

local function entity_create_handle()
    local hierarchy_dirty = false
    for msg in entity_create_mb:each() do
        local eid = msg[2]
        local e = world[eid]
        if e.pickup == nil and e.outline_entity == nil then
            hierarchy_dirty = true
            break
        end
    end
    if hierarchy_dirty then
        send_hierarchy()
    end
end

function editor_watcher_system:update()
    entity_create_handle()
    entity_delete_handle()
end
function editor_watcher_system:after_update()
    local need_send = world:singleton "editor_watcher_cache".need_send
    if not need_send then
        return
    end
    local check = {}
    for i,id in ipairs(need_send) do
        local entity = world[id]
        if entity and entity.editor_watching then
            table.insert(check,id)
        end
    end
    send_entity(check,"auto")
end
