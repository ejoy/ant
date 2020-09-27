local ecs = ...
local world = ecs.world

local viewidmgr     = require "viewid_mgr"
local fbmgr         = require "framebuffer_mgr"
local sampler       = require "sampler"
local ipp           = world:interface "ant.render|postprocess"
local iom           = world:interface "ant.objcontroller|obj_motion"
local imaterial     = world:interface "ant.asset|imaterial"
local irender       = world:interface "ant.render|irender"
local math3d        = require "math3d"

local dof_sys       = ecs.system "dof_system"

function dof_sys.post_init()
    local mq_rt = world:singleton_entity "main_queue".render_target
    
    local fbidx = fbmgr.get_fb_idx(viewidmgr.get "main_view")
    local fbw, fbh = ipp.main_rb_size(fbidx)
    local hfbw, hfbh = fbw/2, fbh/2
    
    local flags = sampler.sampler_flag {
        RT="RT_ON",
        MIN="LINEAR",
        MAG="LINEAR",
        U="CLAMP",
        V="CLAMP",
    }

    local ds_rt = {
        clear_state = {clear=""},
        view_rect = {x=0, y=0, w=hfbw, h=hfbh},
        fb_idx = fbmgr.create{
            fbmgr.create_rb{        --near color
                format = "RGBA16F",
                w=hfbw, h=hfbh,
                layers = 1,
                flags = flags,
            },
            fbmgr.create_rb{        --far color
                format = "RGBA16F",
                w=hfbw, h=hfbh,
                layers = 1,
                flags = flags,
            },
            fbmgr.create_rb{        --coc
                format = "RG16F",
                w=hfbw, h=hfbh,
                layers = 1,
                flags = flags,
            }
        }
    }
    local ds_pass = ipp.create_pass("/pkg/ant.resources/materials/postprocess/dof/downsample.material", ds_rt, "downsample")

    local scatter_rt = {
        clear_state = {clear=""},
        view_rect = {x=0, y=0, w=hfbw, h=hfbh},
        fb_idx = fbmgr.create{
            fbmgr.create_rb{
                format = "RGBA8",
                w=hfbw, h=hfbh,
                layers = 1, flags=flags,
            }
        }
    }
    local scatter_pass = ipp.create_pass("/pkg/ant.resources/materials/postprocess/dof/scatter.material", scatter_rt, "scatter")
    local ds_fb = fbmgr.get(ds_rt.fb_idx)
    imaterial.set_property(scatter_pass.eid, "s_nearBuffer", {stage=0, texture={handle = fbmgr.get_rb(ds_fb[1]).handle}})
    imaterial.set_property(scatter_pass.eid, "s_farBuffer",  {stage=1, texture={handle = fbmgr.get_rb(ds_fb[2]).handle}})
    imaterial.set_property(scatter_pass.eid, "s_cocBuffer",  {stage=2, texture={handle = fbmgr.get_rb(ds_fb[3]).handle}})

    scatter_pass.renderitem.ib = {
        start = 0,
        num = hfbw * hfbh,
        handle = irender.quad_ib(),
    }
    
    local us_rt = {
        clear_state = {clear=""},
        view_rect   = {x=0, y=0, w=fbw, h=fbh},
        fb_idx      = mq_rt.fb_idx,
    }
    local us_pass = ipp.create_pass("/pkg/ant.resources/materials/postprocess/dof/resolve.material", us_rt, "resolve")
    local sp_fb = fbmgr.get(scatter_rt.fb_idx)
    imaterial.set_property(us_pass.eid, "s_scatterBuffer", {stage=0, texture={handle = fbmgr.get_rb(sp_fb[1]).handle}})

    ipp.add_technique("dof", {ds_pass, scatter_pass, us_pass})
end

local function update_dof_param(eid)
    local dof = world[eid]._dof
    
    local function calc_focus_distance(eid, dof)
        local focuseid = dof.focuseid
        if focuseid and world[focuseid] then
            local camerapos = iom.get_position(eid)
            local objpos = iom.get_position(focuseid)
            return math3d.length(camerapos, objpos)
        end

        return dof.focus_distance
    end

    local tech = ipp.get_technique "dof"

    local ds_pass = tech[1]
    local scatter_pass = tech[2]

    local w, h = main_rb_size()

    local focusdist = calc_focus_distance(eid, dof)

    local function to_meter(mm)
        return mm * 0.001
    end
    local focal_len = to_meter(dof.focal_len)
    local aperture = 0.5 * focal_len / dof.aperture_fstop;
    local sensor_size = to_meter(dof.sensor_size)

    local dof_bais = aperture * math.abs(focal_len / (focusdist - focal_len));
    dof_bais = dof_bais *(w / sensor_size);
    local dof_params = {
        -focusdist * dof_bais,
        dof_bais,
        0, 0,
    }

    imaterial.set_property(ds_pass.eid, "u_dof_param", dof_params)

    local bokeh = {dof.aperture_rotation, 1/dof.aperture_ratio, 100, 0}
    imaterial.set_property(scatter_pass.eid, "u_bokeh_param", bokeh)
    
    local blades = dof.aperture_blades
    local twopi = math.pi * 2
    local bokeh_sides = {
        blades,
        blades > 0 and twopi / blades or 0,
        blades / twopi,
        blades > 0 and math.cos(math.pi / blades) or 0,
    }
    imaterial.set_property(scatter_pass.eid, "u_bokeh_sides", bokeh_sides)
end

local dof_register_mb = world:sub{"component_register", "dof"}
local dof_mbs = {}
function dof_sys:data_changed()
    for _, _, eid in dof_register_mb:unpack() do
        update_dof_param(eid)
        world:sub{"component_changed", "dof", eid}
    end

    for _, mb in ipairs(dof_mbs) do
        for _, _, eid in mb:unpack() do
            update_dof_param(eid)
        end
    end
end