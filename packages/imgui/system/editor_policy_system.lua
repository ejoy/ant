local ecs = ...
local world = ecs.world
local WatcherEvent = require "hub_event"

ecs.component_alias("test_component", "boolean")

local test_add_policy = ecs.policy "test_add_policy"
test_add_policy.require_component "test_component"
test_add_policy.require_transform "test_add_policy_transform"

local transform = ecs.transform "test_add_policy_transform"
transform.output "test_component"
function transform.process(e)
    e.test_component = true
end

local editor_policy_system = ecs.system "editor_policy_system"

-- local function on_request_entity_policy(eids)
--     local entity_policies = {}
--     for i in ipairs(eids) do
--         local eid = eids[i] 
--         entity_policies[eid] = world:get_entity_policies(eid)
--     end
--     hub.publish(WatcherEvent.RTE.SendEntityPolicy,entity_policies)
-- end

local function on_request_add_policy(eids,policies_list,data_set)
    log.info_a("on_request_entity_policy",eids,policy_dic)
    local eid = eids[1]
    assert(world[eid])
    world:add_policy(eid,{policy = policies_list,data = data_set})
end

function editor_policy_system:init()
    local hub = world.args.hub
    hub.subscribe(WatcherEvent.ETR.RequestAddPolicy,on_request_add_policy)
end
