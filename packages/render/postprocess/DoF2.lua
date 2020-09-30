local ecs = ...
local world = ecs.world

local sampler   = require "sampler"
local viewidmgr = require "viewid_mgr"
local fbmgr     = require "framebuffer_mgr"

local ipp       = world:interface "ant.render|postprocess"
local iom       = world:interface "ant.objcontroller|obj_motion"
local imaterial = world:interface "ant.asset|imaterial"
local icamera   = world:interface "ant.camera|camera"

local mathpkg   = import_package "ant.math"
local mc        = mathpkg.constant

local simpledof = ecs.system "simpledof_system"

function simpledof.post_init()
    local main_fbidx = fbmgr.get_fb_idx(viewidmgr.get "main_view")
    local fbw, fbh = ipp.main_rb_size(main_fbidx)
    local hfbw, hfbh = fbw/2, fbh/2

    local rbflags = sampler.sampler_flag {
        RT="RT_ON",
        MIN="LINEAR",
        MAG="LINEAR",
        U="CLAMP",
        V="CLAMP",
    }
    
    local blurrt = {
        clear_state = {clear=""},
        view_rect = {x=0, y=0, w=hfbw, h=hfbh},
        fb_idx = fbmgr.create{
            fbmgr.create_rb {
                format = "RGBA16F",
                layers = 1,
                w = hfbw, h = hfbh,
                flags = rbflags,
            }
        },
    }

    local mq = world:singleton_entity "main_queue"
    local blurpass = ipp.create_pass(
        "simpledof_blur", 
        "/pkg/ant.resources/materials/postprocess/dof/simple_blur.material", 
        blurrt, nil, mq.camera_eid)

    local mergert = {
        clear_state = {clear=""},
        view_rect = {x=0, y=0, w=fbw, h=fbh},
        fb_idx = fbmgr.create{
            fbmgr.create_rb {
                format = "RGBA16F",
                layers = 1,
                w = fbw, h = fbh,
                flags = rbflags,
            }
        },
    }

    local mergepass = ipp.create_pass(
        "simpledof_merge",
        "/pkg/ant.resources/materials/postprocess/dof/simple_merge.material",
        mergert, nil, mq.camera_eid)
    local outfocus_handle = fbmgr.get_rb(fbmgr.get(blurrt.fb_idx)[1]).handle
    imaterial.set_property(mergepass.eid, "s_outfocus", {stage=0, texture={handle=outfocus_handle}})
    ipp.add_technique("simpledof", {blurpass, mergepass})
end

local function update_dof_param(e, eid)
    local dof = e._dof

    local tech = ipp.get_technique "simpledof"
    local blurpass, mergepass = tech[1], tech[2]

    local focuseid = dof.focuseid
    imaterial.set_property(mergepass.eid, "u_focuspoint", 
        focuseid and world[focuseid] and iom.get_position(focuseid) or mc.ZERO_PT)

    local f = icamera.get_frustum(eid)
    imaterial.set_property(mergepass.eid, "u_param", {f.n, f.f, 8.0, 12.0})
end

local dof_register_mb = world:sub{"component_register", "camera"}
local dof_mbs = {}

function simpledof.data_changed()
    for _, _, eid in dof_register_mb:unpack() do
        local e = world[eid]
        if e._dof then
            update_dof_param(e, eid)
            world:sub{"component_changed", "camera", "dof", eid}
        end
    end

    for _, mb in ipairs(dof_mbs) do
        for _, _, _, eid in mb:unpack() do
            update_dof_param(eid)
        end
    end

end