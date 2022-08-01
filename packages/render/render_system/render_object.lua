local ecs = ...
local serialize = import_package "ant.serialize"

local rendercore = ecs.clibs "render.core"
local mc = import_package "ant.math".constant

local queuematerials = {}

local ro = ecs.component "render_object"
local function init_ro()
    local qm = rendercore.queue_materials()
    local h = qm:ptr()
    assert(queuematerials[h] == nil)
    queuematerials[h] = qm
    return {
        worldmat    = mc.NULL,
        prog        = 0xffffffff,
        --materials
        mat_mq      = 0,
        mat_predepth= 0,
        mat_scenedepth=0,
        mat_pickup  = 0,
        mat_csm1    = 0,
        mat_csm2    = 0,
        mat_csm3    = 0,
        mat_csm4    = 0,
        mat_lightmap= 0,
        --mesh
        vb_start    = 0,
        vb_num      = 0,
        vb_handle   = 0xffffffff,
        ib_start    = 0,
        ib_num      = 0,
        ib_handle   = 0xffffffff,

        depth       = 0,
        discard_flags=0xff,
        materials   = h,
    }
end

function ro.init(r)
    assert(not r)
    return init_ro()
end

function ro.remove(r)
    assert(queuematerials[r.materials])
    queuematerials[r.materials] = nil
end

function ro.marshal(v)
    return ""
end

function ro.unmarshal(s)
    return init_ro()
end

local ra = ecs.component "render_args2"
function ra.init(v)
    v.visible_id = 0
    v.cull_id = 0
    v.viewid = 0
    v.material_idx = 0
end

