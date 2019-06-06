local ecs = ...
local world = ecs.world
local WatcherEvent = require "hub_event"
local serialize = import_package 'ant.serialize'

ecs.tag "editor_watching"

local editor_watcher_system = ecs.system "editor_watcher_system"

local function send_hierarchy()
    local result = {}
    for _,eid in world:each("name") do
        result[eid] = {name = world[eid].name,children = nil}
    end
    local hub = world.args.hub
    hub.publish(WatcherEvent.HierarchyChange,result)
    return
end

local function start_watch_entities(eids)
    if eids[1] then
        local camerautil = import_package "ant.render".camera
        camerautil.focus_selected_obj(world, eids[1])
    end
    local hub = world.args.hub
    print_a("start_watch_entities",eids)
    local old_eids = {}
    for _, eid in world:each("editor_watching") do
        table.insert(old_eids,eid)
    end
    
    for _,eid in ipairs(old_eids) do
        world:remove_component(eid,"editor_watching")
        print(">>remove_component editor_watching:",eid)
    end
    local setialize_result = {}
    for _,eid in ipairs(eids) do
        world:add_component(eid,"editor_watching",false)
        print(">>add_component editor_watching:",eid)
        setialize_result[eid] = serialize.entity2tbl(world,eid)
    end

    -- print_a(setialize_result)
    hub.publish(WatcherEvent.EntityChange,setialize_result)
end

local function on_component_modified(eid,id,key,value)
    print_a("on_component_modified",id,key,value)
    if not id then
        serialize.watch.set(world,nil,eid,key,value)
    else
        serialize.watch.set(world,id,"",key,value)
    end
    print_a("after_component_modified:",serialize.watch.query(world,id,""))
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

local function publish_world_info()
    local pm = require "antpm"
    local packages = pm.get_registered_list()
    local schemas = copy_table(world._schema.map)
    -- local pack = 
    -- hub.subscribe(WatcherEvent.RESPONSE_WORLD_INFO,)
    local hub = world.args.hub
    hub.publish(WatcherEvent.RESPONSE_WORLD_INFO,{packages = packages,schemas = schemas})
end

function editor_watcher_system:init()
    local hub = world.args.hub
    
    hub.subscribe(WatcherEvent.WatchEntity,start_watch_entities)
    hub.subscribe(WatcherEvent.ModifyComponent,on_component_modified)
    -- hub.subscribe(WatcherEvent.REQUEST_WORLD_INFO,publish_world_info)
    -- publish_world_info()
end

function editor_watcher_system:after_update()
    local hierarchy_dirty = false
    if world._last_entity_id  ~= world._entity_id then
        hierarchy_dirty = true
    elseif self._removed and #self._removed >0 then
        hierarchy_dirty = true
    end
    if hierarchy_dirty then
        world._last_entity_id = world._entity_id
        send_hierarchy()
    end
end
