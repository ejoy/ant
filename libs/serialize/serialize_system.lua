local ecs = ...
local world = ecs.world

local save_world = ecs.component "save_world"{}

function save_world:init()
    self.dirty = true
end

local serialize_save_sys = ecs.system "serialize_save_system"
serialize_save_sys.singleton "serialize_tree"
serialize_save_sys.singleton "save_world"
serialize_save_sys.singleton "math_stack"

serialize_save_sys.depend "end_frame"

local function save_entity(eid, ms)
    local cl = world:component_list(eid)
    local e = assert(world[eid])
    local e_tree = {}

    local arg = {world=world, math_stack = ms, eid = eid}

	for _, v in ipairs(cl) do
        local save_comp = assert(world._component_type[v].save)
        local c = e[v]
        arg.comp = v
        local s = save_comp(c, arg)
        e_tree[v] = s
    end
    
    return e_tree
end

local test = false

function serialize_save_sys:update()
    if self.save_world.dirty then
        local children = {}
        for _, eid in world:each("serialize") do        
            local tr = save_entity(eid, self.math_stack)
            table.insert(children, tr)
        end
    
        self.serialize_tree.root = children
        self.save_world.dirty = false
        test = true
    end
end

--- load system

local load_world = ecs.component "load_world"{}
function load_world:init()
    self.dirty = true
end

local serialize_load_sys = ecs.system "serialize_load_system"

serialize_load_sys.singleton "math_stack"
serialize_load_sys.singleton "serialize_tree"
serialize_load_sys.singleton "load_world"

serialize_load_sys.depend "end_frame"


local function load_entity(tree, ms)
    local eid = world:new_entity()
    local entity = world[eid]
    local arg = {
        world = world, 
        math_stack = ms, 
        eid = eid
    }

	for k, v in pairs(tree) do
        local load_comp = assert(world._component_type[k].load)
        world:add_component(eid, k)
        arg.comp = k
        load_comp(entity[k], v, arg)
    end
    
    return eid
end

local function post_load(loaded_eids)
    for _, eid in world:each("hierarchy_name_mapper") do
        if loaded_eids[eid] then
            local e = world[eid]
            local name_mapper = e.hierarchy_name_mapper
            for n, uuid in ipairs(name_mapper.v) do
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

function serialize_load_sys:update()
    if self.load_world.dirty and test then
        local children = self.serialize_tree.root
        local loaded_eids = {}
        for _, tr in ipairs(children) do
            local eid = load_entity(tr, self.math_stack)
            loaded_eids[eid] = true
        end

        post_load(loaded_eids)

        self.load_world.dirty = false

        test = false
    end
end