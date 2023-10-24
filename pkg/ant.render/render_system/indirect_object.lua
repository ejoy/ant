local ecs = ...

local ido = ecs.component "indirect_object"

function ido.init()
    return {
        idb_handle  = 0xffffffff,
        itb_handle  = 0xffffffff,
        draw_num    = 0,
    }
end
