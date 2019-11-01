graphic = {
    api = "mteal",
    shadow = {
        enable = true,
        type = "inv_z",
        split_num = 4,
    },

    hdr = {
        enable = false,
        format = "RGBA16"   -- "RGBA32"
    },
    
    postprocess = {
        bloom = {
            enable = false,
            sample_times = 4,
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