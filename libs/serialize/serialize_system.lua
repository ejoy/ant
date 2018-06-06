local ecs = ...
local world = ecs.world

local su = require "serialize.util"

local serialize_save_sys = ecs.system "serialize_save_system"
serialize_save_sys.singleton "serialization_tree"
serialize_save_sys.singleton "math_stack"

serialize_save_sys.depend "end_frame"

function serialize_save_sys.notify:save()
    local children = {}
    for _, eid in world:each("serialize") do        
        local tr = su.save_entity(world, eid, self.math_stack)
        table.insert(children, tr)
    end

    world:change_component(-1, "save_tofile")
    world:notify()

    self.serialization_tree.root = children
    self.serialization_tree.name = "test_world"
end

--- load system
local serialize_load_sys = ecs.system "serialize_load_system"

serialize_load_sys.singleton "math_stack"
serialize_load_sys.singleton "serialization_tree"

serialize_load_sys.depend "end_frame"

local function post_load(loaded_eids)
    for _, eid in world:each("hierarchy_name_mapper") do
        if loaded_eids[eid] then
            local e = world[eid]
            local name_mapper = e.hierarchy_name_mapper.v
            for n, uuid in pairs(name_mapper) do
                local function find_eid(uuid)
                    for _, eid in world:each("serialize") do
                        local e = world[eid]
                        local serialize = e.serialize
                        if serialize.uuid == uuid then
                            return eid
                        end
                    end
    
                    return nil
                end
    
                local found_eid = find_eid(uuid)
                if found_eid then
                    name_mapper[n] = found_eid
                else
                    print(string.format("not found uuid = %s by hierarchy_name_mapper in world, name is : %s", uuid, n))
                end
            end
        end
    end
end

function serialize_load_sys.notify:load_from_seri_tree()
    local children = assert(self.serialization_tree.root)
    assert(#children ~= 0)
    local loaded_eids = {}
    for _, tr in ipairs(children) do
        local eid = su.load_entity(tr, self.math_stack)
        loaded_eids[eid] = true
    end

    post_load(loaded_eids)
end

--- test save&load system, only for test purpose
local serialize_test_sys = ecs.system "serialize_test_system"
serialize_test_sys.singleton "message_component"

function serialize_test_sys:init()
    local message = {}
    function message:keypress(c, p)
        if c == nil then return end

        if p then
            if c == "cS" then
                world:change_component(-1, "save")
                world:notify()
            elseif c == "cL" then
                world:change_component(-1, "load_from_luatext")
                world:notify()
            end
        end

    end

    self.message_component.msg_observers:add(message)
end
