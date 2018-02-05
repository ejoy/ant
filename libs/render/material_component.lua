local ecs = ...

--[@    render state
local render_util = require "ant.util"
local bgfx = require "bgfx"

local materil = {
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

function materil.new()
    local tt = {}
    setmetatable(tt, {__index = materil})
    return tt
end

function create_render_state()
    return materil.new()
end
--@]

--[@    textures
local texture_res_mapper = {
    texArray = {
        "",
    }, -- texture path
    remapper = {    
        --vs = {0},   -- vertex stage  
        fs = {0},     -- fragment stage  
    }
}

function texture_res_mapper.new()
    local tt = {}
    setmetatable(tt, {__index = texture_res_mapper})
    return tt
end

function create_tex_res_mapper()
    return texture_res_mapper.new()
end
--@]

--[@    shader
local shader_res = {
    vs = {  
        path = "",
    },
    ps = {
        path = "",
    },
    prog = 0
}

function shader_res.new()
    local tt = {}
    setmetatable(tt, {__index = shader_res})
    return tt
end
--@]

--[@    uniforms
local uniform = {
    name = "",
    type = "v4",
    value_calculator = function () return {} end,
    uniform_id = 0,
}

function uniform.new()
    local tt = {}
    setmetatable(tt, {__index = uniform})
    return tt
end

function create_uniform_data()
    return uniform.new()
end

--@]


--[@    render state component
local materil = ecs.component "materil" {
    state           = create_render_state(),
    tex_res_mapper  = create_tex_res_mapper(),
    shader          = shader_res.new(),
    uniforms        = {},
}

local materil_sys = ecs.system "materil_system"
materil_sys.singleton("materil", "math3d")

function materil_sys:init()
    -- all this init should read from file

    local shader = self.materil.shader

    shader.vs.path = "vs_mesh"  
    shader.ps.path = "ps_mesh"
    
    shader.prog = render_util.programLoad(shader.vs.path, shader.ps.path)

    local uniforms = self.materil.uniforms
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


local materail_unfirom_update_sys = ecs.system "materail_unfirom_update_system"
materail_unfirom_update_sys.singleton("material", "math3d")

function materail_unfirom_update_sys:update()

end

--local render_state_update_sys = ecs.system "render_state_update_system"

--@]