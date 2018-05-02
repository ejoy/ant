local ecs = ...
local world = ecs.world

local save_world = ecs.component "save_world"{}

function save_world:init()
    self.dirty = true
end

local world_magicnum = '>!w<'
local entity_magicnum = '>!e<'

local serialize_save_sys = ecs.system "serialize_save_system"
serialize_save_sys.singleton "serialize_intermediate_format"
serialize_save_sys.singleton "save_world"

serialize_save_sys.depend "end_frame"

local function save_entity(eid)
    local cl = world:component_list(eid)
    local e = assert(world[eid])
    local e_tree = {}

	for _, v in ipairs(cl) do
        local save_comp = assert(world._component_type[v].save)
        local c = e[v]
        local s = save_comp(c)
        e_tree[v] = s
    end
    
    return e_tree
end

function serialize_save_sys:update()
    if self.save_world.dirty then
        local serialization_tree = {}
        for _, eid in world:each("serialize") do        
            local tr = save_entity(eid)
            serialization_tree[eid] = tr
        end
    
        self.serialize_intermediate_format.tree = serialization_tree
        self.save_world.dirty = false
    end
end

--- load system

local load_world = ecs.component "load_world"{}
function load_world:init()
    self.dirty = true
end

local serialize_load_sys = ecs.system "serialize_load_system"

serialize_load_sys.singleton "math_stack"
serialize_load_sys.singleton "serialize_intermediate_format"
serialize_load_sys.singleton "load_world"

serialize_load_sys.depend "end_frame"

local function load_entity(tree)
    local eid = world:new_entity()
	local entity = world[eid]

	for k, v in pairs(tree) do
        local load_comp = assert(world._component_type[k].load)
        world:add_component(eid, k)
        load_comp(entity[k], v)
    
    end
    
    return eid
end

function serialize_load_sys:update()

    if false and self.load_world.dirty then
        local tree = self.serialize_intermediate_format.tree
        for k, v in pairs(tree) do
            load_entity(v)
        end
        self.load_world.dirty = false
    end
end