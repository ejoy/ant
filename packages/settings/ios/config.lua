graphic = {
    shadow = {
        enable = true,
        type = {
            value = "inv_z",
            fallback = "linear",
        },
        split_num = {
            value = 4,
            fallback = 1,
        },
    },

    hdr = {
        enable = false,
        format = "RGBA16"   -- "RGBA32"
    },
    
    postprocess = {
        bloom = {
            enable = false,
            sample_times = {
                value = 4,
                fallback = 1,
            },
        },
    },
}

animation = {
    skinning = {
        type = {
            value = "GPU",
            fallback = "CPU",
        },
        CPU = {
            enable = true,
            max_indices = {
                value = 5,
                fallback = 4,
            },
        },
        GPU = {
            enable = true,
        }
    }
}