local ecs = ...
local world = ecs.world
local WatcherEvent = require "hub_event"
local serialize = import_package 'ant.serialize'
local fs = require "filesystem"
local mathpkg = import_package "ant.math"
local mu = mathpkg.util

local Rx        = import_package "ant.rxlua".Rx

local OperateFunc = require "system.editor_operate_func"

ecs.tag "editor_watching"
ecs.tag "outline_entity"

ecs.component_alias("target_entity","entityid")
ecs.tag "editor_object"


local outline_policy = ecs.policy "outline"
outline_policy.require_component "outline_entity"
outline_policy.require_component "target_entity"
outline_policy.require_component "editor_object"


local editor_watcher_system = ecs.system "editor_watcher_system"
editor_watcher_system.require_system "editor_operate_gizmo_system"
editor_watcher_system.require_system "editor_policy_system"
editor_watcher_system.require_system 'ant.scene|scene_space' 
editor_watcher_system.require_system 'editor_entity_system' 
editor_watcher_system.require_interface "ant.objcontroller|camera_motion"

local camera_motion = world:interface "ant.objcontroller|camera_motion"


-- editor_watcher_system.require_system "before_render_system"
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
    hub.publish(WatcherEvent.RTE.HierarchyChange,result)
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

local function get_entity_policies(eids)
    local entity_policies = {}
    for i in ipairs(eids) do
        local eid = eids[i] 
        entity_policies[eid] = world:get_entity_policies(eid)
    end
    return entity_policies
end

local function entity2tbl(w, eid)
    return serialize.watch.query(w, eid, "")
end

local last_eid = nil
local last_tbl = nil
local timer = world:interface "ant.timer|timer"
local function send_entity(eids,typ)
    local profile_cache = world:singleton "profile_cache"
    local hub = world.args.hub
    local entity_info = {type = typ}
    if eids == nil or (not world[eids[1]]) then
        hub.publish(WatcherEvent.RTE.EntityInfo,entity_info)
        last_eid = nil
        last_tbl = nil
        log.info_a("send_entity","nothing")
    else
        local setialize_result = {}
        table.insert(profile_cache,{"editor_watcher_system","entity2tbl","begin",timer.current()})
        for i,eid in ipairs(eids) do
            if world[eid] then
                setialize_result[eid] = entity2tbl(world,eid)
            end
        end
        table.insert(profile_cache,{"editor_watcher_system","entity2tbl","end",timer.current()})
        if compare_values(last_eid,eids) then
            table.insert(profile_cache,{"editor_watcher_system","compare_values","begin",timer.current()})
            local b = compare_values(last_tbl,setialize_result)
            table.insert(profile_cache,{"editor_watcher_system","compare_values","end",timer.current()})
            if b then
                return
            end
        end
        last_eid = eids
        last_tbl = setialize_result
        entity_info.entities = setialize_result
        entity_info.policies = get_entity_policies(eids)
        entity_info.eids = eids
        hub.publish(WatcherEvent.RTE.EntityInfo,entity_info)
        -- log.info_a("send_entity",eids)
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

-- local function make_follow(follower_id,target_id)
    
-- end

--todo put to pipeline
local function pub_follow_per_frame()
    for _,id in world:each("outline_entity") do
        local follower = world[id]
        if follower then
            --todo has bug with follow comment now
            world:pub({"update_follow",id,follower.transform.parent})
        end
    end
end


local function create_outline(seleid)
    local computil  = import_package "ant.render".components
    local se = world[seleid]
    if se then
        -- if not se.hierarchy then
        --     world:add_component(seleid,"hierarchy",{})
        -- end

        -- local trans = se.transform
        -- local s, r, t = ms(trans.t, trans.r, trans.s, "TTT")
        local t = {srt = mu.srt()}
        t.parent = world[seleid].serialize
        local outlineeid = world:create_entity {
            policy={
                -- "ant.render|name",
                "ant.render|render",
                "ant.scene|hierarchy",
                "ant.imgui|outline",
            },
            data={
                transform = t,
                rendermesh = {},
                material = "/pkg/ant.resources/depiction/materials/outline/scale.material",
                can_render = true,
                outline_entity = true,
                target_entity = world[seleid].serialize,
                hierarchy = {},
                hierarchy_visible = true,
                editor_object = true
                -- name = "outline_object"
            },
           
        }
        local oe = world[outlineeid]
        oe.rendermesh.reskey = se.rendermesh.reskey
        world:pub { "material_change",outlineeid }
        -- assetmgr.load(se.rendermesh.reskey)
        -- world:pub({"begin_follow",outlineeid,seleid,nil})
        world:pub({"update_follow",outlineeid,seleid})
    end
end

local function change_watch_entity(eids,focus,is_pick)
    local adds = {}
    local remove_map = {}
    local olds_map = {}
    for _,id in world:each("editor_watching") do
        olds_map[id] = true
    end
    -- log.info_a(olds_map,olds_map)
    for _,id in ipairs(eids or {}) do
        if olds_map[id] then
            olds_map[id] = nil
        else
            table.insert(adds,id)
        end
    end
    for id,_ in pairs(olds_map) do
        remove_map[id] = true
    end
    -- log.info_a("remove_map",remove_map)
    --remove tag:editor_watching,show_operate_gizmo
    for id,_ in pairs(remove_map) do
        world:disable_tag(id,"editor_watching")
        if world[id].show_operate_gizmo then
            world:disable_tag(id,"show_operate_gizmo")
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
        log.info("if (not eids) or #eids <= 0 then")
        return 
    end
    local last_eid = eids[#eids]
    if focus then
        --todo calc multselect center
        local mq = world:singleton_entity "main_queue"
        local camera_id = mq.camera_eid
        camera_motion.focus_obj(camera_id,last_eid)
    end
    local need_send = {}
    for _, eid in ipairs( eids ) do
        local target_ent = world[eid]
        if target_ent.serialize then
            if target_ent.can_select then
                create_outline(eid)
            end
            world:enable_tag(eid,"editor_watching")
            if target_ent.transform then
                world:enable_tag(eid,"show_operate_gizmo")
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
            world:disable_tag(id,"editor_watching")
            if world[id].show_operate_gizmo then
                world:disable_tag(id,"show_operate_gizmo")
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
                    camerautil.focus_point(world, transform.srt.t)
                end
            end
        end
        local target_ent = world[eid]
        if target_ent then
            if target_ent.can_select then
                create_outline(eid)
            end
            world:enable_tag(eid,"editor_watching")
            if target_ent.transform then
                world:enable_tag(eid,"show_operate_gizmo")
            end
            log.trace(">>enable_tag [editor_watching] to:",eid)
            send_entity({eid},( is_pick and "pick" or "editor"))
        end
    end
    return change_watch_entity({eid},focus,is_pick)
end

local function on_editor_select_entity(self,eids,focus)
    log.info_a("on_editor_select_entity",eids,focus)
    -- for i,eid in ipairs(eids) do 
    --     if world[eid] and (not world[eid].gizmo_object) then
    --         start_watch_entitiy(eid,focus,false)
    --     end
    -- end
    change_watch_entity(eids,focus,false)
end

local function on_pick_entity(eid)
    log.info_a("on_pick_entity",eid)
    if eid then
        if world[eid] and (not world[eid].gizmo_object) then
            change_watch_entity({eid},false,true)
        end
    else
        change_watch_entity(nil,false,true)
    end
end

local function on_component_modified(eid,parent_path,key,value)
    log.trace_a("on_component_modified",eid,parent_path,key,value)
    if key == nil then -- entity
        if not serialize.watch.set(world,eid,"",value) then
            log.warning_a("modify entity failed",eid,value)
        end
        log.trace_a("after_entity_modified:",serialize.watch.query(world,eid,full_path))
    else --com
        local full_path
        if parent_path ~= "" then
            full_path = parent_path.."/"..key
        else
            full_path = key
        end
        local first_com = full_path:match("^[^/]+")
        serialize.watch.set(world,eid,full_path,value)
        world:pub {"component_changed", first_com, eid, {}}
        log.trace_a("after_component_modified:",serialize.watch.query(world,eid,full_path))
    end
end

local function on_mult_component_modified(eids,parent_path,key,value,is_list)
    log.trace_a("on_mult_component_modified",eids,parent_path,key,value,is_list)
    if key == nil then --entity
        if is_list then
            for i,eid in ipairs(eids) do
                if not serialize.watch.set(world,eid,"",value[i]) then
                    log.warning_a("modify entity failed",eid,value)
                end
                log.trace_a("after_entity_modified:",serialize.watch.query(world,eid,full_path))
            end
        else
            for i,eid in ipairs(eids) do
                if not serialize.watch.set(world,eid,"",value) then
                    log.warning_a("modify entity failed",eid,value)
                end
                log.trace_a("after_entity_modified:",serialize.watch.query(world,eid,full_path))
            end
        end
    else
        local full_path
        if parent_path ~= "" then
            full_path = parent_path .."/"..key
        else
            full_path = key
        end
        local first_com = full_path:match("^[^/]+")
        if is_list then -- value is a list for every entity
            for i,eid in ipairs(eids) do
                if serialize.watch.set(world,eid,full_path,value[i]) then
                    world:pub {"component_changed", first_com, eids[i]}
                end
                log.trace_a("after_component_modified:",serialize.watch.query(world,eid,full_path))
            end
        else
            for i,eid in ipairs(eids) do
                if serialize.watch.set(world,eid,full_path,value) then
                    world:pub {"component_changed", first_com, eids[i]}
                end
                log.trace_a("after_component_modified:",serialize.watch.query(world,eid,full_path))
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

local function on_entity_operate( self,event,args )
    log.info_a(event,args)
    OperateFunc(self,world,event,args)
end

local function on_request_hierarchy(self)
    send_hierarchy()
end

function editor_watcher_system:init()
    local hub = world.args.hub
    hub.subscribe(WatcherEvent.ETR.WatchEntity,on_editor_select_entity,self)
    hub.subscribe(WatcherEvent.ETR.ModifyComponent,on_component_modified)
    hub.subscribe(WatcherEvent.ETR.ModifyMultComponent,on_mult_component_modified)
    hub.subscribe(WatcherEvent.ETR.EntityOperate,on_entity_operate,self)
    hub.subscribe(WatcherEvent.ETR.RequestHierarchy,on_request_hierarchy,self)
    local profile_cache = world:singleton "profile_cache"
    -- hub.subscribe(WatcherEvent.ETR.RequestWorldInfo,publish_world_info)
    -- publish_world_info()
    local rxbus = world.args.rxbus
    local watchentity_ob = rxbus:get_observable(WatcherEvent.ETR.WatchEntity)
    watchentity_ob:subscribe(Rx.handler(on_editor_select_entity,self))
end

local pickup_mb = world:sub {"pickup"}
function editor_watcher_system:after_pickup()
    for _,pick_id,pick_ids in pickup_mb:unpack() do
        local hub = world.args.hub
        local eid = pick_id
        if eid and world[eid] then
            if not world[eid].gizmo_object then
                hub.publish(WatcherEvent.RTE.SceneEntityPick,{eid})
                on_pick_entity(eid)
            end
        else
            hub.publish(WatcherEvent.RTE.SceneEntityPick,{})
            on_pick_entity(nil)
        end
    end
end

local timer = world:interface "ant.timer|timer"

local entity_delete_mb = world:sub {"entity_removed"}
local entity_create_mb = world:sub {"entity_created"}
local name_change_mb = world:sub {"component_changed","name"}
local entity_relation_change_mb = world:sub {"entity_relation_change"}
local function is_entity_delete()
    local hierarchy_dirty = false
    for msg in entity_delete_mb:each() do
        local e = msg[3]
        if not e or (e.pickup == nil and e.outline_entity == nil) then
            hierarchy_dirty = true
            entity_create_mb:clear()
            break
        end
    end
    return hierarchy_dirty
end

local function is_entity_create()
    local hierarchy_dirty = false
    for msg in entity_create_mb:each() do
        local eid = msg[2]
        local e = world[eid]
        --e may be deleted already
        if e and e.pickup == nil and e.outline_entity == nil then
            hierarchy_dirty = true
            entity_create_mb:clear()
            break
        end
    end
    return hierarchy_dirty
end

local function is_entity_name_change()
    for _ in name_change_mb:each() do
        name_change_mb:clear()
        return true
    end
end

local function is_entity_relation_change()
    for _ in entity_relation_change_mb:each() do
        entity_relation_change_mb:clear()
        return true
    end
end


function editor_watcher_system:editor_update()
    --这里本来应该条件短路掉，但是为了清空事件，还是全部调用一次
    local conditions = {
        is_entity_create(),
        is_entity_delete(),
        is_entity_name_change(),
        is_entity_relation_change(),
    }
    for _,b in ipairs(conditions) do
        send_hierarchy()
        break
    end
    --check name
    pub_follow_per_frame()
end

function editor_watcher_system:after_update()
    -----
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
