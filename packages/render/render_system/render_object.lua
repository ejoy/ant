local ecs = ...

local mc = import_package "ant.math".constant
local rendercore = ecs.clibs "render.core"
local null = rendercore.null()

local ro = ecs.component "render_object"
local function init_ro()
    return {
        worldmat    = mc.NULL,
        prog        = 0xffffffff,
        --materials
        mat_mq      = null,
        mat_predepth= null,
        mat_scenedepth=null,
        mat_pickup  = null,
        mat_csm1    = null,
        mat_csm2    = null,
        mat_csm3    = null,
        mat_csm4    = null,
        mat_lightmap= null,
        --mesh
        vb_start    = 0,
        vb_num      = 0,
        vb_handle   = 0xffffffff,
        ib_start    = 0,
        ib_num      = 0,
        ib_handle   = 0xffffffff,

        depth       = 0,
        discard_flags=0xff,
    }
end

function ro.init(r)
    assert(not r)
    return init_ro()
end

function ro.remove(r)
    
end

function ro.marshal(v)
    return ""
end

function ro.unmarshal(s)
    return init_ro()
end

local ra = ecs.component "render_args"
function ra.init(v)
    v.visible_id = 0
    v.cull_id = 0
    v.viewid = 0
    v.material_idx = 0
end

