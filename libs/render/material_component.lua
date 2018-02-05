local ecs = ...

local render_util = require "ant.util"

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


local render_state = ecs.component "render_state" {
    state = get_rs_hw(),
    tex_res_mapper = texture_res_mapper(),
    shader = shader_res.new()
}

local render_state_init_system = ecs.component "rs_init_system"
render_state_init_system.singleton "render_state"

function render_state_init_system:init()
    --self.render_state.state
    --print("default render state")
    local shader = self.shader

    --[@    to do, wiil read from file. hard code here
    shader.vs.path = "vs_mesh"  
    shader.ps.path = "ps_mesh"
    --@]
    
    shader.prog = render_util.programLoad(shader.vs.path, shader.ps.path)
end
