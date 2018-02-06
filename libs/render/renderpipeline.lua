local ecs = ...
local world = ecs.world
local bgfx = require "bgfx"
local ant = require "lbgfx"
local util = require "lbgfx.util"

local world_mat_comp = ecs.component "worldmat_comp" {
    mat = {type = "matrix"}
}

local function for_each_comp_in_world(compNames, op)
    for eid in world:each(compNames[0]) do
        local entity = world[eid]
        if entity ~= nil then
            function is_entity_have_components(beg_idx, end_idx)
                while beg_idx ~= end_idx do
                    if entity[compNames[beg_idx]] == nil then
                        return false
                    end
                    beg_idx = beg_idx + 1
                end
                return true
            end
            
            if is_entity_have_components(2, #compNames) then
                op(entity)
            end
        end
    end
end


--[@
local rpl_system = ecs.system "render_pipeline"

function rpl_system:init()

end

local function draw_mesh(mesh, shader)
    local groups = mesh.group
    for i = 1, #group do
        local group = groups[i]
        bgfx.set_index_buffer(group.ib)
        bgfx.set_vertex_buffer(group.vb)
        bgfx.submit(0, shader.prog, 0, i ~= n)
    end
end

local function update_uniform(uniforms) 
    for i = 1, #uniforms do
        local unifrom = uniforms[i]
        local value = unifrom:value_calculator()
        bgfx.set_uniform(unifrom.uniform_id, value)
    end
end

local auto_rotate_worldmat_sys = ecs.system "rotate_worldmat_system"
auto_rotate_worldmat_sys.singleton "math3d"

local time = 0
function auto_rotate_worldmat_sys:update()
    local speed = 1
    time = time + speed

    for_each_comp_in_world({"worldmat_comp"},
    function (entity)
        --entity.world_mat_comp.mat = entity.math3d(entity.world_mat_comp, {time}, "*M") 
    end)
end

function rpl_system:update()
    bgfx.set_view_clear(0, "CD", 0x303030ff, 1, 0)
    bgfx.touch(0)
    for_each_comp_in_world({"mesh", "worldmat_comp", "material"},
    function (entity)        
        --bgfx.set_transfrom(entity.worldmat_comp.mat)    
        
        local material = entity.material
        bgfx.set_state(material.state)
        
        update_uniform(material.uniforms)       
        draw_mesh(entity.mesh, material.shader)
    end)

    bgfx.frame()
end

--@]