local ecs = ...
local world = ecs.world
local WatcherEvent = require "hub_event"
local serialize = import_package 'ant.serialize'
local fs = require "filesystem"

ecs.tag "editor_watching"

local editor_watcher_system = ecs.system "editor_watcher_system"

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
        elseif not pid and e.hierarchy_transform then
            pid = e.hierarchy_transform.parent
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
    return
end

local function send_entity(eid,typ)
    local hub = world.args.hub
    local entity_info = {type = typ}
    local setialize_result = {}
    setialize_result[eid] = serialize.entity2tbl(world,eid)
    entity_info.entities = setialize_result 
    -- log.info_a(setialize_result)
    hub.publish(WatcherEvent.EntityInfo,entity_info)
    -- if is_pick then
    --     hub.publish(WatcherEvent.EntityInfo,setialize_result)
    -- else
    --     hub.publish(WatcherEvent.EntityChange,setialize_result)
    -- end
end

local function start_watch_entitiy(eid,is_pick)
    if (not eid) or (not world[eid]) then
        return
    end
    if eid and ( not is_pick ) then
        local camerautil = import_package "ant.render".camera
        -- camerautil.focus_selected_obj(world, eid)
        local transform = world[eid].transform or world[eid].hierarchy_transform
        camerautil.focus_point(world, transform.t)
    end
    local hub = world.args.hub
    local old_eids = {}
    for _, id in world:each("editor_watching") do
        table.insert(old_eids,id)
    end
    
    for _,id in ipairs(old_eids) do
        world:remove_component(id,"editor_watching")
        log.trace(">>remove_component editor_watching:",id)
    end
    if world[eid] then
        world:add_component(eid,"editor_watching",true)
        log(">>add_component editor_watching:",eid)
        send_entity(eid,( is_pick and "pick" or "editor"))
    end
end

local function on_component_modified(eid,com_id,key,value)
    log.trace_a("on_component_modified",com_id,key,value)
    if not com_id then
        serialize.watch.set(world,nil,eid,key,value)
        log.trace_a("after_component_modified:",serialize.watch.query(world,nil,eid))
    else
        serialize.watch.set(world,com_id,"",key,value)
        log.trace_a("after_component_modified:",serialize.watch.query(world,com_id,""))
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


function editor_watcher_system:init()
    local hub = world.args.hub
    hub.subscribe(WatcherEvent.WatchEntity,start_watch_entitiy)
    hub.subscribe(WatcherEvent.ModifyComponent,on_component_modified)
    -- hub.subscribe(WatcherEvent.RequestWorldInfo,publish_world_info)
    -- publish_world_info()
end

function editor_watcher_system:pickup()
    local pickupentity = world:first_entity "pickup"
    if pickupentity then
        local pickupcomp = pickupentity.pickup
        local eid = pickupcomp.pickup_cache.last_pick
        if world[eid] then
            local hub = world.args.hub
            hub.publish(WatcherEvent.EntityPick,{eid})
            start_watch_entitiy(eid,true)
        end
    end

end

function editor_watcher_system:after_update()
    local hierarchy_dirty = false
    if world._last_entity_id  ~= world._entity_id then
        for i = (world._last_entity_id or 0) + 1,world._entity_id do
            if world[i] and (not world[i].pickup) then
                hierarchy_dirty = true
                break
            end
        end
        world._last_entity_id = world._entity_id
    end
    if world._removed and #world._removed >0 then
        for _,e in ipairs(world._removed) do
            if e[2] and (e[2].pickup == nil) then
                hierarchy_dirty = true
                break
            end
        end
    end
    if hierarchy_dirty then
        world._last_entity_id = world._entity_id
        send_hierarchy()
    end
    local eid = world:first_entity_id("editor_watching")
    if eid then
        send_entity(eid,"auto")
    end
end
