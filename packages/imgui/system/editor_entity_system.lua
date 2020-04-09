local ecs = ...
local world = ecs.world
local Event = require "hub_event"
local serialize = import_package 'ant.serialize'
local fs = require "filesystem"
local mathpkg = import_package "ant.math"
local mu = mathpkg.util
local ms = mathpkg.stack
local Rx        = import_package "ant.rxlua".Rx

local editor_entity_system = ecs.system "editor_entity_system"
local hub = world.args.hub

ecs.component "entity_relation"
    .parent_child_dic "int{}"
    .child_parent_dic "int{}"
ecs.singleton "entity_relation" {
    parent_child_dic = {},
    child_parent_dic = {},
}
editor_entity_system.require_singleton "entity_relation"


local poll_parent_msg
local refresh_parent_relation

local function on_request_new_entity(arg)
    if arg then
        local parent = arg.parent
        local policy = arg.policy
        local data = arg.data
        local str = arg.str
        --todo
    else
        local eid = world:instantiate_entity(
            {
                policy={
                    "ant.imgui|base_entity"
                },
                data={
                    name="Entity",
                    transform={
                        s = {1, 1, 1, 0},
                        r = {0, 0, 0, 1},
                        t = {0, 0, 0, 1},
                    },
                    serialize = -1,
                }
            }
        )
        hub.publish(Event.RTE.ResponseNewEntity,{eid})
    end
end

local function rename_duplicate_entity(eid)
    local entity_relation = world:singleton "entity_relation"
    local parent_child_dic = entity_relation.parent_child_dic
    local child_parent_dic = entity_relation.child_parent_dic
    poll_parent_msg() --update parent-children info
    local entity = world[eid]
    if entity.name then
        local parent = world[eid].transform and world[eid].transform.parent
        if parent then
            local name_dic = {}
            local children = parent_child_dic[parent]
            for _,id in ipairs(children) do
                if world[id].name then
                    name_dic[world[id].name] = true
                end
            end
            for i = 1,100000 do
                local new_name = string.format("%s(%d)",entity.name,i)
                if not name_dic[new_name] then
                    entity.new_name = new_name
                    world:pub("component_changed","name",eid)
                    break
                end
            end
        else
            local name_dic = {}
            for _,id in world:each("name") do
                if (not world[id].transform) or (not world[id].transform.parent) then
                    name_dic[world[id].name] = true
                end
            end
            for i = 1,100000 do
                local new_name = string.format("%s(%d)",entity.name,i)
                if not name_dic[new_name] then
                    entity.name = new_name
                    world:pub("component_changed","name",eid)
                    break
                end
            end
        end
    end

end

local function on_request_duplicate_entity(eids)
    local entity_relation = world:singleton "entity_relation"
    local parent_child_dic = entity_relation.parent_child_dic
    local child_parent_dic = entity_relation.child_parent_dic
    --when duplicate parent,need duplicate children too. 
    poll_parent_msg()
    local include_flag = {}
    local trees = {} -- {parent={child={},...}}
    local function fetch_children(children,parent)
        if parent_child_dic[parent] then
            for _,eid in ipairs(parent_child_dic[parent]) do
                if world[eid] then
                    if not world[eid].editor_object then
                        assert(not include_flag[eid],"parent child info conflicted")
                        include_flag[eid] = true
                        children[eid] = {}
                        fetch_children(children[eid],eid)
                    end
                end
            end
        end
    end
    for _,eid in ipairs(eids) do
        if not include_flag[eid] then
            include_flag[eid] = true
            trees[eid] = {} 
            fetch_children(trees[eid],eid)
        end
    end
    log.info_a("duplicate entity:",trees)
    local created_eids = {}
    local function create_children(dic)
        for eid,children in pairs(dic) do
            local policy = world:get_entity_policies(eid)
            local str = serialize.serialize_entity(world,eid,policy)
            local new_eid = world:instantiate_entity(str)
            rename_duplicate_entity(new_eid)
            table.insert(created_eids,new_eid)
            create_children(children)
        end
    end
    create_children(trees)
    log.info_a("create entitys:",created_eids)
    hub.publish(Event.RTE.ResponseDuplicateEntity,created_eids)
end

local relation_mb_list = {}
table.insert(relation_mb_list,{world:sub {"component_changed","transform"},3}) --3
table.insert(relation_mb_list,{world:sub {"component_changed","parent"},3}) --3
table.insert(relation_mb_list, {world:sub {"component_register","transform",eid},3}) --3
table.insert(relation_mb_list, {world:sub {"entity_created",eid},2}) --2
table.insert(relation_mb_list, {world:sub {"entity_removed",eid},2}) --2

function editor_entity_system:init()
    hub.subscribe(Event.ETR.NewEntity,on_request_new_entity)
    hub.subscribe(Event.ETR.DuplicateEntity,on_request_duplicate_entity)
    --todo create parent_child_dic&child_parent_dic
    for _,eid in world:each("transform") do
        refresh_parent_relation(eid)
    end
end

local function refresh_parent_relation(target)
    local dirty = false
    local entity_relation = world:singleton "entity_relation"
    local parent_child_dic = entity_relation.parent_child_dic
    local child_parent_dic = entity_relation.child_parent_dic
    if not world[target] then
        --when remove child
        local old_parent = child_parent_dic[target]
        if old_parent then -- is child
            local old_child_list = parent_child_dic[old_parent]
            assert(old_child_list,"child_parent_dic&parent_child_dic data conflict")
            for i,eid in ipairs(old_child_list) do
                if eid == target then
                    table.remove(old_child_list,i)
                    break
                end
            end
            child_parent_dic[target] = nil
            dirty = true
        end
        --when remove parent
        --todo?
    else
        --change
        local new_parent_id = world[target].transform and world[target].transform.parent
        local old_parent_id = child_parent_dic[target]
        if new_parent_id ~= old_parent_id then
            child_parent_dic[target] = new_parent_id
            dirty = true
            if old_parent_id then
                local old_child_list = parent_child_dic[old_parent_id]
                assert(old_child_list,"child_parent_dic&parent_child_dic data conflict")
                for i,eid in ipairs(old_child_list) do
                    if eid == target then
                        table.remove(old_child_list,i)
                        break
                    end
                end
            end
            if new_parent_id then
                parent_child_dic[new_parent_id] = parent_child_dic[new_parent_id] or {}
                local new_children = parent_child_dic[new_parent_id] 
                --check
                local is_child = true
                for _,eid in ipairs(new_children) do
                    if eid == target then
                        is_child = false
                        break
                    end
                end
                if is_child then
                    table.insert(new_children,target)
                end
            end
        end
    end
    world:pub {"entity_relation_change"}
end

function poll_parent_msg()
    for _,msg_info in ipairs(relation_mb_list) do
        local mb = msg_info[1]
        local id_index = msg_info[2]
        for msg in mb:each() do
            local eid = msg[id_index]
            refresh_parent_relation(eid)
        end
    end

end

function editor_entity_system:editor_update()
    poll_parent_msg()
end