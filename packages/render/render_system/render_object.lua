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
        mesh        = 0,
        depth       = 0,
        discardflags= 0xff,
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
    return serialize.pack(v)
end

function ro.unmarshal(s)
    return serialize.unpack(s)
end

local ra = ecs.component "render_args2"
function ra.init(v)
    v.visible_id = 0
    v.cull_id = 0
    v.viewid = 0
    v.material_idx = 0
end


local iqm = ecs.interface "iqueue_materials"

local function get_qm(ro)
    local h = ro.materials
    return queuematerials[h]
end

function iqm.set_property(e, who, what, qn)
    qn = qn or "main_queue"
    local qm = get_qm(e.render_object)
    local m = qm[qn]
    m[who] = what
end

iqm.get_materials = get_qm
