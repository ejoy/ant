local ecs = ...
local world = ecs.world
local bgfx = require "bgfx"

local render_uril = require "render.render_util"

local world_mat_comp = ecs.component "worldmat_comp" {
    mat = {type = "matrix"}
}

--[@
local auto_rotate_worldmat_sys = ecs.system "rotate_worldmat_system"
auto_rotate_worldmat_sys.singleton "math_stack"

local time = 0
function auto_rotate_worldmat_sys:update()
    local speed = 1
    time = time + speed

    render_uril.for_each_comp(world, {"worldmat_comp"},
    function (entity)
        --entity.world_mat_comp.mat = entity.math_stack(entity.world_mat_comp, {time}, "*M") 
    end)
end
--@]

--[@
local rpl_system = ecs.system "render_pipeline"

rpl_system.depend "add_entities_system"
rpl_system.depend "camera_system"
rpl_system.depend "viewport_system"

function rpl_system:init()

end

local function draw_mesh(mesh, shader)
    local prog = assert(shader.prog)
    local num = #mesh.group

    for i=1, num do        
        local g = mesh.group[i]
        bgfx.set_index_buffer(g.ib)
        bgfx.set_vertex_buffer(g.vb)
        bgfx.submit(0, prog, 0, i ~= num)
    end
end

local function update_uniform(uniforms) 
    --for i = 1, #uniforms do    
    for _, u in pairs(uniforms) do
        local value = u:update()
        bgfx.set_uniform(u.id, value)
    end
end

function rpl_system:update() 
    bgfx.touch(0)

    --print("rpl_system:update")
    render_uril.for_each_comp(world, {"mesh", "worldmat_comp", "material"},
    function (entity)        
        --bgfx.set_transfrom(entity.worldmat_comp.mat)
        local material = entity.material        
        bgfx.set_state(bgfx.make_state(material.state)) -- always convert to state str
        
        update_uniform(material.uniforms)
        draw_mesh(entity.mesh.handle, material.shader)
    end)

    bgfx.frame()
end

--@]