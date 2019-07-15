local ecs = ...
local world = ecs.world
local WatcherEvent = require "hub_event"
local serialize = import_package 'ant.serialize'
local fs = require "filesystem"

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

local function start_watch_entitiy(eid)
    log.trace_a("start_watch_entitiy",eid)
    if eid then
        -- local camerautil = import_package "ant.render".camera
        -- camerautil.focus_selected_obj(world, eid)
    end
    local hub = world.args.hub
    log.trace_a("start_watch_entitiy",eid)
    local old_eids = {}
    for _, id in world:each("editor_watching") do
        table.insert(old_eids,id)
    end
    
    for _,id in ipairs(old_eids) do
        world:remove_component(id,"editor_watching")
        log.trace(">>remove_component editor_watching:",id)
    end
    local setialize_result = {}
    if world[eid] then
        world:add_component(eid,"editor_watching",false)
        log(">>add_component editor_watching:",eid)
        setialize_result[eid] = serialize.entity2tbl(world,eid)

        -- log.info_a(setialize_result)
        hub.publish(WatcherEvent.EntityChange,setialize_result)
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
