local texture_table = {
    path_table = {
        [1] = "/pkg/ant.resources/textures/color_text.texture",
        [2] = "/pkg/ant.resources/textures/irbtn_active.texture",
        [3] = "/pkg/ant.resources/textures/irbtn_hover.texture",
        [4] = "/pkg/ant.resources/textures/irbtn_normal.texture"
    },
    rect_table = {
        ["color_text_L"] = {
            path_idx = 1,
            rect = {x = 0, y = 0, w = 64, h = 64}
        },
        ["color_text_R"] = {
            path_idx = 1,
            rect = {x = 64, y = 0, w = 64, h = 64}
        },
        ["color_text_T"] = {
            path_idx = 1,
            rect = {x = 128, y = 0, w = 64, h = 64}
        },
        ["color_text_B"] = {
            path_idx = 1,
            rect = {x = 192, y = 0, w = 64, h = 64}
        },
        ["color_text_N"] = {
            path_idx = 1,
            rect = {x = 256, y = 0, w = 64, h = 64}
        },
        ["color_text_F"] = {
            path_idx = 1,
            rect = {x = 320, y = 0, w = 64, h = 64}
        },
        ["irbtn_active"] = {
            path_idx = 2,
            rect = {x = 0, y = 0, w = 512, h = 512}
        },
        ["irbtn_hover"] = {
            path_idx = 3,
            rect = {x = 0, y = 0, w = 512, h = 512}
        },
        ["irbtn_normal"] = {
            path_idx = 4,
            rect = {x = 0, y = 0, w = 512, h = 512}
        },
    }
}

return texture_table