local ecs = ...
local world = ecs.world
local mc = import_package "ant.math".constant

local ro = ecs.component "render_object"
local INVALID_VALUE<const> = 0xffffffff

function ro.init()
    return {
        worldmat    = mc.NULL,

        --DO NOT call R.alloc/Q.alloc here, or we need to handle marsal/unmarsal

        --materials
        rm_idx      = INVALID_VALUE,

        --queue indices
        visible_idx = INVALID_VALUE,
        cull_idx    = INVALID_VALUE,

        --mesh
        vb_start    = 0,
        vb_num      = 0,
        vb_handle   = INVALID_VALUE,
        vb2_start   = 0,
        vb2_num     = 0,
        vb2_handle  = INVALID_VALUE,
        ib_start    = 0,
        ib_num      = 0,
        ib_handle   = INVALID_VALUE,
        render_layer= 0,
        discard_flags=0xff,
    }
end