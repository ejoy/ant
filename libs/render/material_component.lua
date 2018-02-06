local ecs = ...

--[@    render state
local render_util = require "lbgfx.util"
local bgfx = require "bgfx"


function create_render_state()
    return {
        RGB_WRITE = true,   --acutally we should provide r, g, b write
        ALPHA_WRITE = true,
        ALPHA_REF = 0,
        CULL = "CCW",
        MSAA = true,
        PT = "TRISTRIP",    --
    
        BLEND_ENABLE = false,
        --BLEND = "ADD",
        --BLEND_FUNC,
        --BLEND_FUNC_RT,
        --BLEND_EQUATION,
    
        DEPTH_WRITE = true,
        DEPTH_TEST = "LESS",
        --POINT_SIZE
    }
end
--@]

--[@    textures
function create_tex_res_mapper()
    return {
        texArray = {
            "",
        }, -- texture path
        remapper = {    
            --vs = {0},   -- vertex stage  
            fs = {0},     -- fragment stage  
        }
    }
end
--@]

function create_shader_data()
    return {
        vs_path = "",
        ps_path = "",
        prog    = 0
    }
end

--[@    uniforms
function create_uniform_data()
    return {
        name = "",
        type = "v4",
        value_calculator = function () return {} end,
        uniform_id = 0,
    }
end
--@]

--[@    render state component
local material = ecs.component "material" {
    state           = {type = "userdata", create_render_state},
    tex_res_mapper  = {type = "userdata", create_tex_res_mapper},
    shader          = {type = "userdata", create_shader_data},
    uniforms        = {type = "userdata", {}},
}

local material_sys = ecs.system "material_system"

material_sys.singleton "material"
material_sys.singleton "math3d"

function material_sys:init()
    -- all this init should read from file
    
    local shader = self.material.shader

    shader.vs_path = "vs_mesh"  
    shader.ps_path = "ps_mesh"
    
    shader.prog = render_util.programLoad(shader.vs_path, shader.ps_path)

    local uniforms = self.material.uniforms
    local uniform = create_uniform_data()
    uniform.name = "u_time"
    uniform.type = "v4"
    local time = 0
    uniform.value_calculator = function ()
        time = time + 1
        return {time}
    end
    uniform.uniform_id = bgfx.create_uniform(uniform.name, unifrom.type)
    table.insert(uniforms, uniform.name, uniform)
end


-- local materail_unfirom_update_sys = ecs.system "materail_unfirom_update_system"
-- materail_unfirom_update_sys.singleton("material", "math3d")

-- function materail_unfirom_update_sys:update()

-- end

--local render_state_update_sys = ecs.system "render_state_update_system"

--@]