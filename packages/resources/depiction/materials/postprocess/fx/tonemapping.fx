local shaderpath = "/pkg/ant.resources/depiction/materials/postprocess/fx/"
shader = {
    vs = shaderpath .. "vs_pp_quad.sc",
    fs = shaderpath .. "fs_tonemapping.sc",
}

surface_type = {
    lighting = "off",
    shadow = {
        cast = "off",
        receive = "off",
    },
}