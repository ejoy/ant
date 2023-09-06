local ecs = ...

local mc = import_package "ant.math".constant

local ro = ecs.component "render_object"

function ro.init()
    return {
        worldmat    = mc.NULL,
        prog        = 0xffffffff,
        --materials
        rm_idx      = 0xffffffff,
        visible_masks = 0,
        cull_masks  = 0,
        --mesh
        vb_start    = 0,
        vb_num      = 0,
        vb_handle   = 0xffffffff,
        vb2_start    = 0,
        vb2_num      = 0,
        vb2_handle   = 0xffffffff,
        ib_start    = 0,
        ib_num      = 0,
        ib_handle   = 0xffffffff,
        idb_handle  = 0xffffffff,
        itb_handle  = 0xffffffff,
        draw_num    = 0xffffffff,
        render_layer= 0,
        discard_flags=0xff,
    }
end
