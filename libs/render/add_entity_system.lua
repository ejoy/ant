local ecs = ...

local world = ecs.world

local add_entity_sys = ecs.system "add_entities_system"

function add_entity_sys:init()
    -- add bunny entity, to do : need to change: [material] name to [bunny_material], [mesh] name to [bunny_mesh]
    -- [material] and [mesh] is the "class", and [bunny_material]/[bunny_mesh] should be instance
    world:new_entity("worldmat_comp", "material", "mesh")   

    -- same with the material
    world:new_entity("view_transform", "frustum")
end
