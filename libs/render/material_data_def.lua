local material_data = {}

function material_data.create_render_state()
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
function material_data.create_tex_res_mapper()
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

function material_data.create_shader_data()
    return {
        vs_path = "",
        ps_path = "",
        prog    = 0
    }
end

function material_data.create_uniform_data()
    return {
        name = "",
        type = "v4",
        value_calculator = function () return {} end,
        uniform_id = 0,
    }
end

return material_data