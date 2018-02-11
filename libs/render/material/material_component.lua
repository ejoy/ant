local ecs = ...

local material = ecs.component "material" {
    state           = {type = "asset", "libs/render/material/data_def/default.state"},
    tex_res_mapper  = {type = "asset", "libs/render/material/data_def/default.tex_mapper"},
    shader          = {type = "asset", "libs/render/material/data_def/default.shader"},
    uniforms        = {type = "userdata", {}},
}

