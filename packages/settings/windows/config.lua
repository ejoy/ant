graphic = {
    api = "d3d11",
    shadow = {
        enable = true,
        size = 1024,
        type = "inv_z",
        split_num = 4,
    },

    hdr = {
        enable = true,
        format = "RGBA16F"   -- "RGBA32F"
    },
    
    postprocess = {
        bloom = {
            enable = true,
            sample_times = 4,
            format = "RGBA16F"
        },
    },
}

animation = {
    skinning = {
        type = "CPU",
        CPU = {
            enable = true,
            max_indices = 5,
        },
        GPU = {
            enable = true,
        }
    }
}