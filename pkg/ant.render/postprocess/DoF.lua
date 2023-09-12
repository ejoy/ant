local ecs = ...
local world = ecs.world

-- local hwi           = import_package "ant.hwi"
-- local fbmgr         = require "framebuffer_mgr"
-- local sampler       = import_package "ant.render.core".sampler
-- local ipp           = ecs.require "ant.render|postprocess"
-- local iom           = ecs.require "ant.objcontroller|obj_motion"
-- local imaterial = ecs.require "ant.asset|material"
-- local irender       = ecs.require "ant.render|render_system.render"
-- local math3d        = require "math3d"

-- local dof_sys       = ecs.system "dof_system"

-- function dof_sys.post_init()
--     local main_fbidx = fbmgr.get_fb_idx(hwi.viewid_get "main_view")
--     local fbw, fbh = ipp.main_rb_size(main_fbidx)
--     local hfbw, hfbh = fbw/2, fbh/2
    
--     local flags = sampler {
--         RT="RT_ON",
--         MIN="LINEAR",
--         MAG="LINEAR",
--         U="CLAMP",
--         V="CLAMP",
--     }

--     local ds_rt = {
--         clear_state = {clear=""},
--         view_rect = {x=0, y=0, w=hfbw, h=hfbh},
--         fb_idx = fbmgr.create{
--             fbmgr.create_rb{        --near color
--                 format = "RG11B10F",
--                 w=hfbw, h=hfbh,
--                 layers = 1,
--                 flags = flags,
--             },
--             fbmgr.create_rb{        --far color
--                 format = "RG11B10F",
--                 w=hfbw, h=hfbh,
--                 layers = 1,
--                 flags = flags,
--             },
--             fbmgr.create_rb{        --coc
--                 format = "RG16F",
--                 w=hfbw, h=hfbh,
--                 layers = 1,
--                 flags = flags,
--             }
--         }
--     }
--     local ds_pass = ipp.create_pass("downsample", "/pkg/ant.resources/materials/postprocess/dof/downsample.material", ds_rt)

--     local scatter_rt = {
--         clear_state = {clear=""},
--         view_rect = {x=0, y=0, w=hfbw, h=hfbh},
--         fb_idx = fbmgr.create{
--             fbmgr.create_rb{
--                 format = "RGBA32F",
--                 w=fbw*2, h=fbh,
--                 layers = 1, flags=flags,
--             }
--         }
--     }
--     local scatter_pass = ipp.create_pass("scatter", "/pkg/ant.resources/materials/postprocess/dof/scatter.material", scatter_rt)
--     local ds_fb = fbmgr.get(ds_rt.fb_idx)
--     imaterial.set_property(scatter_pass.eid, "s_nearBuffer", {stage=0, texture={handle = fbmgr.get_rb(ds_fb[1]).handle}})
--     imaterial.set_property(scatter_pass.eid, "s_farBuffer",  {stage=1, texture={handle = fbmgr.get_rb(ds_fb[2]).handle}})
--     imaterial.set_property(scatter_pass.eid, "s_cocBuffer",  {stage=2, texture={handle = fbmgr.get_rb(ds_fb[3]).handle}})

--     do
--         local ri = scatter_pass.renderitem
--         ri.ib = nil
--         local vb = ri.vb
--         ri.vb = {
--             start = 0,
--             num = (hfbw * hfbh) * 3,
--             handle = vb.handle
--         }
--     end
    
--     local us_rt = {
--         clear_state = {clear="C", color=0},
--         view_rect   = {x=0, y=0, w=fbw, h=fbh},
--         fb_idx      = main_fbidx
--     }
--     local us_pass = ipp.create_pass("resolve", "/pkg/ant.resources/materials/postprocess/dof/resolve.material", us_rt)
--     local sp_fb = fbmgr.get(scatter_rt.fb_idx)
--     imaterial.set_property(us_pass.eid, "s_scatterBuffer", {stage=0, texture={handle = fbmgr.get_rb(sp_fb[1]).handle}})

--     ipp.add_technique("dof", {ds_pass, scatter_pass, us_pass})
-- end

-- local function update_dof_param(e, eid)
--     local dof = e._dof
    
--     local function calc_focus_distance(eid, dof)
--         local focuseid = dof.focuseid
--         if focuseid and world[focuseid] then
--             local camerapos = iom.get_position(eid)
--             local objpos = iom.get_position(focuseid)
--             return math3d.length(camerapos, objpos)
--         end

--         return dof.focus_distance
--     end

--     local cr = e._rendercache.clip_range

--     local tech = ipp.get_technique "dof"

--     local ds_pass, scatter_pass, resolve_pass = tech[1], tech[2], tech[3]

--     local main_fbidx = fbmgr.get_fb_idx(viewidmgr.get "main_view")
--     local fbw   = ipp.main_rb_size(main_fbidx)

--     --- downsample
--     local focusdist = calc_focus_distance(eid, dof)

--     local function to_meter(mm)
--         return mm * 0.001
--     end
--     local focal_len = to_meter(dof.focal_len)
--     local aperture = 0.5 * focal_len / dof.aperture_fstop;
--     local sensor_size = to_meter(dof.sensor_size)

--     local dof_bais = aperture * math.abs(focal_len / (focusdist - focal_len));
--     dof_bais = dof_bais * (fbw / sensor_size);
--     local dof_param = {
--         -focusdist * dof_bais,
--         dof_bais,
--         cr[1], cr[2]
--     }

--     imaterial.set_property(ds_pass.eid, "u_dof_param", dof_param)

--     --- scatter
--     local bokeh = {dof.aperture_rotation, 1/dof.aperture_ratio, 100, 0}
--     imaterial.set_property(scatter_pass.eid, "u_bokeh_param", bokeh)
    
--     local blades = dof.aperture_blades
--     local twopi = math.pi * 2
--     local bokeh_sides = {
--         blades,
--         blades > 0 and twopi / blades or 0,
--         blades / twopi,
--         blades > 0 and math.cos(math.pi / blades) or 0,
--     }
--     imaterial.set_property(scatter_pass.eid, "u_bokeh_sides", bokeh_sides)

--     --- resolve
--     imaterial.set_property(resolve_pass.eid, "u_dof_param", dof_param)
-- end

-- local dof_register_mb = world:sub{"component_register", "camera"}
-- local dof_mbs = {}
-- function dof_sys:data_changed()
--     for _, _, eid in dof_register_mb:unpack() do
--         local e = world[eid]
--         if e._dof then
--             update_dof_param(e, eid)
--             world:sub{"component_changed", "camera", "dof", eid}
--         end
--     end

--     for _, mb in ipairs(dof_mbs) do
--         for _, _, _, eid in mb:unpack() do
--             update_dof_param(eid)
--         end
--     end
-- end