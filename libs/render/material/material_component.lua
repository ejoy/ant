local ecs = ...

--[@    render state

local material_util = require "render.material.material_data_def"

--[@    render state component
local material = ecs.component "material" {
    state           = {type = "userdata", material_util.create_render_state},
    tex_res_mapper  = {type = "userdata", material_util.create_tex_res_mapper},
    shader          = {type = "userdata", material_util.create_shader_data},
    uniforms        = {type = "userdata", {}},
}

