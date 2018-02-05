local ecs = ...

--[@    render state
local render_util = require "ant.util"
local bgfx = require "bgfx"

local rs_hw = {
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

function rs_hw.new()
    local tt = {}
    setmetatable(tt, {__index = rs_hw})
    return tt
end

function get_rs_hw()
    return rs_hw.new()
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

function get_tex_res_mapper()
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
local render_state = ecs.component "render_state" {
    state = get_rs_hw(),
    tex_res_mapper = texture_res_mapper(),
    shader = shader_res.new(),
    uniforms = {},
}

local render_state_system = ecs.component "render_state_system"
render_state_system.singleton "render_state"

function render_state_system:init()
    local shader = self.render_state.shader

    --[@    to do, wiil read from file. hard code here
    shader.vs.path = "vs_mesh"  
    shader.ps.path = "ps_mesh"
    --@]
    
    shader.prog = render_util.programLoad(shader.vs.path, shader.ps.path)

    local uniforms = self.render_state.uniforms
    local uniform = create_uniform_data()
    uniform.name = "u_time"
    uniform.type = "v4"
    uniform.uniform_id = bgfx.create_uniform(uniform.name, unifrom.type)
    table.insert(uniforms, #uniforms, uniform)
end

function render_state_system:update()

end

--local render_state_update_sys = ecs.system "render_state_update_system"

--@]