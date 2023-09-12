local ecs = ...
local world = ecs.world
-- local w = world.w
-- local sampler       = import_package "ant.render.core".sampler
-- local fbmgr     = require "framebuffer_mgr"

-- local ipp       = ecs.require "ant.render|postprocess"
-- local iom       = ecs.require "ant.objcontroller|obj_motion"
-- local imaterial = ecs.require "ant.asset|material"
-- local icamera   = ecs.require "ant.camera|camera"

-- local mathpkg   = import_package "ant.math"
-- local mc        = mathpkg.constant

-- local simpledof = ecs.system "simpledof_system"

-- function simpledof.entity_init()
--     for e in w:select "INIT main_queue camera_ref:in render_target:in" do
--         local main_fbidx = e.render_target.fb_idx
--         local fbw, fbh = ipp.main_rb_size(main_fbidx)
--         local hfbw, hfbh = fbw/2, fbh/2

--         local rbflags = sampler {
--             RT="RT_ON",
--             MIN="LINEAR",
--             MAG="LINEAR",
--             U="CLAMP",
--             V="CLAMP",
--         }
        
--         local blurrt = {
--             clear_state = {clear=""},
--             view_rect = {x=0, y=0, w=hfbw, h=hfbh},
--             fb_idx = fbmgr.create{
--                 fbmgr.create_rb {
--                     format = "RGBA16F",
--                     layers = 1,
--                     w = hfbw, h = hfbh,
--                     flags = rbflags,
--                 }
--             },
--         }
--         local blurpass = ipp.create_pass(
--             "simpledof_blur", 
--             "/pkg/ant.resources/materials/postprocess/dof/simple_blur.material", 
--             blurrt, nil, e.camera_ref)

--         local mergert = {
--             clear_state = {clear=""},
--             view_rect = {x=0, y=0, w=fbw, h=fbh},
--             fb_idx = fbmgr.create{
--                 fbmgr.create_rb {
--                     format = "RGBA16F",
--                     layers = 1,
--                     w = fbw, h = fbh,
--                     flags = rbflags,
--                 }
--             },
--         }

--         local mergepass = ipp.create_pass(
--             "simpledof_merge",
--             "/pkg/ant.resources/materials/postprocess/dof/simple_merge.material",
--             mergert, nil, e.camera_ref)
--         local outfocus_handle = fbmgr.get_rb(fbmgr.get(blurrt.fb_idx)[1]).handle
--         imaterial.set_property(mergepass.eid, "s_outfocus", outfocus_handle)
--         ipp.add_technique("simpledof", {blurpass, mergepass})
--     end
-- end

-- local function update_dof_param(e, eid)
--     local dof = e._dof

--     local tech = ipp.get_technique "simpledof"
--     local blurpass, mergepass = tech[1], tech[2]

--     local focuseid = dof.focuseid
--     imaterial.set_property(mergepass.eid, "u_focuspoint", 
--         focuseid and world[focuseid] and iom.get_position(focuseid) or mc.ZERO_PT)

--     local f = icamera.get_frustum(eid)
--     imaterial.set_property(mergepass.eid, "u_param", {f.n, f.f, 8.0, 12.0})
-- end

-- local dof_register_mb = world:sub{"component_register", "camera"}
-- local dof_mbs = {}

-- function simpledof.data_changed()
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