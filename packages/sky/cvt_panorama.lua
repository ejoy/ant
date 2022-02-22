local ecs   = ...
local world = ecs.world
local w     = world.w

local bgfx  = require "bgfx"

local renderpkg = import_package "ant.render"
local viewidmgr, fbmgr = renderpkg.viewidmgr, renderpkg.fbmgr
local sampler   = renderpkg.sampler

local mathpkg   = import_package "ant.math"
local mc        = mathpkg.constant

local ientity   = ecs.import.interface "ant.render|ientity"
local irq       = ecs.import.interface "ant.render|irenderqueue"
local irender   = ecs.import.interface "ant.render|irender"
local imaterial = ecs.import.interface "ant.asset|imaterial"

local cvt_p2cm_viewid = viewidmgr.generate "cvt_p2cm"

local cvt_p2cm_sys = ecs.system "cvt_p2cm_system"

w:register{
    name = "cvt_p2cm_queue"
}

w:register {
    name = "cvt_p2cm_drawer"
}

function cvt_p2cm_sys:init()
    ecs.create_entity{
        policy = {
            "ant.render|render_queue",
            "ant.general|name",
        },
        data = {
            name = "cvt_p2cm_queue",
            cvt_p2cm_queue = true,
            queue_name = "cvt_p2cm_queue",
            render_target = {
                viewid = cvt_p2cm_viewid,
                view_rect = {x=0, y=0, w=1, h=1},
                clear_state = {
                    color = 0,
                    depth = 1,
                    stencil = 0,
                    clear = "CDS"
                },
                fb_idx = nil,
            },
            primitive_filter = {
				filter_type = "",
			},
            visible = false,
            camera_ref = ecs.create_entity{
                policy = {
                    "ant.camera|camera",
                    "ant.general|name"
                },
                data = {
                    scene = {srt={}},
                    camera = {
                        frustum = {
                            type="mat", n=1, f=1000, fov=0.5, aspect=1,
                        },
                    },
                    name = "camera.cvt_p2cm",
                }
            }
        }
    }

    ecs.create_entity{
        policy = {
            "ant.render|simplerender",
            "ant.general|name",
        },
        data = {
            simplemesh = ientity.simple_fullquad_mesh(),
            material = "/pkg/ant.sky/cvt_p2cm.material",
            scene = {srt={}},
            filter_state = "",
            cvt_p2cm_drawer = true,
            name = "cvt_p2cm_drawer",
        }
    }

end

local cubemap_flags<const> = sampler.sampler_flag {
    MIN="LINEAR",
    MAG="LINEAR",
    MIP="LINEAR",
    U="CLAMP",
    V="CLAMP",
    W="CLAMP",
    RT="RT_ON",
}

local function convert(tex)
    local ti = tex.texinfo
    assert(ti.width==ti.height*2 or ti.width*2==ti.height)
    local size = math.min(ti.width, ti.height) // 2

    local cm_rbidx = fbmgr.create_rb{format="RGBA32F", size=size, layers=1, mipmap=true, flags=cubemap_flags, cubemap=true}
    local q = w:singleton("cvt_p2cm_queue", "render_target:in queue_name:in")
    local rt = q.render_target
    local drawer = w:singleton("cvt_p2cm_drawer", "render_object:in")
    local s_tex = {stage=0, texture=tex}
    for i=1, 6 do
        local fbidx = fbmgr.create{
            rbidx = cm_rbidx,
            layer = i-1,
            resolve = "g",
            mip = 0,
            numlayer = 1,
        }

        rt.fb_idx = fbidx
        local vr = rt.view_rect
        vr.x, vr.y, vr.w, vr.h = 0, 0, size, size
        irq.update_rendertarget(q.queue_name, rt)
        local ro = drawer.render_object
        ro.worldmat = mc.IDENTITY_MAT
        imaterial.set_property_directly(ro.properties, "s_tex", s_tex)

        irender.draw(rt.viewid, ro)
        local keep_rbs<const> = true
        fbmgr.destroy(fbidx, keep_rbs)
    end

    return fbmgr.get_rb(cm_rbidx).handle
end

return {
    convert = convert
}