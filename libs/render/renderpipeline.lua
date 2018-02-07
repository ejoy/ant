local ecs = ...
local world = ecs.world
local bgfx = require "bgfx"
local ant = require "lbgfx"
local util = require "lbgfx.util"
local render_uril = require "render.render_util"

local world_mat_comp = ecs.component "worldmat_comp" {
    mat = {type = "matrix"}
}

--[@
local auto_rotate_worldmat_sys = ecs.system "rotate_worldmat_system"
auto_rotate_worldmat_sys.singleton "math3d"

local time = 0
function auto_rotate_worldmat_sys:update()
    local speed = 1
    time = time + speed

    render_uril.for_each_comp_in_world(world, {"worldmat_comp"},
    function (entity)
        --entity.world_mat_comp.mat = entity.math3d(entity.world_mat_comp, {time}, "*M") 
    end)
end
--@]

--[@
local rpl_system = ecs.system "render_pipeline"

rpl_system.depend "add_entities_system"

function rpl_system:init()

end

local function draw_mesh(mesh, shader)
    local prog = shader.prog
    for _, g in ipairs(mesh.group) do        
        bgfx.set_index_buffer(g.ib)
        bgfx.set_vertex_buffer(g.vb)
        bgfx.submit(0, prog, 0, true)
    end
end

local function update_uniform(uniforms) 
    --for i = 1, #uniforms do
    for u in ipairs(uniforms) do
        local value = u:value_calculator()
        bgfx.set_uniform(u.uniform_id, value)
    end
end

function rpl_system:update()    
    bgfx.set_view_clear(0, "CD", 0x303030ff, 1, 0)
    bgfx.touch(0)

    --print("rpl_system:update")
    render_uril.for_each_comp_in_world(world, {"mesh", "worldmat_comp", "material"},
    function (entity)        
        --bgfx.set_transfrom(entity.worldmat_comp.mat)
        local material = entity.material
        bgfx.set_state(material.state_str)
        
        update_uniform(material.uniforms)
        draw_mesh(entity.mesh.mesh_ref, material.shader)
    end)

    bgfx.frame()
end

--@]