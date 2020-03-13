local ecs = ...
local world = ecs.world
local Event = require "hub_event"
local serialize = import_package 'ant.serialize'
local fs = require "filesystem"
local mathpkg = import_package "ant.math"
local mu = mathpkg.util
local ms = mathpkg.stack
local assetmgr = import_package "ant.asset".mgr
local Rx        = import_package "ant.rxlua".Rx

local editor_entity_system = ecs.system "editor_entity_system"


local function on_request_new_entity(arg)
    if arg then
        local parent = arg.parent
        local policy = arg.policy 
        local data = arg.data
        local str = arg.str
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
    end
end

local function on_request_duplicate_entity(eids)
    poll_parent_msg()
end

local transform_mb = world:sub {"component_changed","transform",eid}
local parent_mb = world:sub {"component_changed","parent",eid}
local parent_child_dic = {}
local child_parent_dic = {}
function editor_entity_system:init()
    hub.publish(Event.ETR.NewEntity,on_request_new_entity)
    hub.publish(Event.ETR.DuplicateEntity,on_request_duplicate_entity)
    --todo create parent_child_dic&child_parent_dic
end

local function poll_parent_msg()
    local function refresh_parent(child)
        local new_parent_id = world[child].transform.parent
        local old_parent_id = child_parent_dic[child]
        if new_parent_id == old_parent_id then
            return
        end
        if old_parent_id then
            local old_parent_list = parent_child_dic[old_parent_id]
            assert(old_parent_list,"child_parent_dic&parent_child_dic data conflict")
            for i,eid in ipairs(old_parent_list) do
                if eid == child then
                    table.remove(old_parent_list,i)
                    break
                end
            end
        end
        
        parent_child_dic[new_parent_id] = parent_child_dic[new_parent_id] or {}
        local new_parent_list = parent_child_dic[new_parent_id] 
        --check
        for _,eid in ipairs(new_parent_list) do
            if eid == child then
                return
            end
        end
        table.insert(new_parent_list,child)
    end
    for _,_,eid in transform_mb:unpack() do
        refresh_parent(eid)
    end
    for _,_,eid in parent_mb:unpack() do
        refresh_parent(eid)
    end
end

function editor_entity_system:editor_update()
    poll_parent_msg()
end