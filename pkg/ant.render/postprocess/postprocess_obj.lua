local ecs   = ...

local irl = ecs.import.interface "ant.render|irender_layer"
local pp_obj_sys = ecs.system "postprocess_obj_system"

function pp_obj_sys:init()
    irl.add_layers(irl.layeridx "background", "postprocess_obj")
end