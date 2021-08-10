local ecs = ...
local world = ecs.world
local w = world.w
local fbmgr             = require "framebuffer_mgr"
local viewidmgr         = require "viewid_mgr"
local isys_properties   = world:interface "ant.render|system_properties"
local ientity           = world:interface "ant.render|entity"
local irender           = world:interface "ant.render|irender"
local irq               = world:interface "ant.render|irenderqueue"

local mathpkg           = import_package "ant.math"
local mc                = mathpkg.constant

local bgfx              = require "bgfx"

local pp_sys            = ecs.system "postprocess_system"
local ipp = ecs.interface "postprocess"

local techniques = {}
local tech_order = {
    --"simpledof", --"dof"
    "bloom", "tonemapping",
}

local function iter_tech()
    return function (t, idx)
        idx = idx + 1
        local n = t[idx]
        if n then
            return idx, techniques[n]
        end
    end, tech_order, 0
end

local quad_mesh_eid

local function local_postprocess_views(num)
    local viewids = {}
    local name = "postprocess"
    for i=1, num do
        viewids[#viewids+1] = viewidmgr.get(name .. i)
    end
    return viewids
end

local postprocess_viewids = local_postprocess_views(10)

local viewid_idx = 0
local function next_viewid()
    viewid_idx = viewid_idx + 1
    return postprocess_viewids[viewid_idx]
end

local function reset_viewid_idx()
    viewid_idx = 0
end

function pp_sys:init()
end

local mainview_rbhandle
function pp_sys:entity_init()
    if mainview_rbhandle == nil then
        for e in w:select "INIT main_queue render_target:in" do
            local fbidx = e.render_target.fb_idx
            mainview_rbhandle = ipp.get_rbhandle(fbidx, 1)
        end
    end
end

local function render_pass(input, out_viewid, pass)
    local rt        = pass.render_target
    local fbidx     = rt.fb_idx or fbmgr.get_fb_idx(viewidmgr.get "main_view")
    local output    = ipp.get_rbhandle(fbidx, 1)
    input           = pass.input or input
    if input == output then
        error("input and output as same render buffer handle")
    end

    if pass.camera_eid then
        local camera_rc = world[pass.camera_eid]._rendercache
        bgfx.set_view_transform(out_viewid, camera_rc.viewmat, camera_rc.projmat)
    else
        bgfx.set_view_transform(out_viewid, mc.IDENTITY_MAT, mc.IDENTITY_MAT)
    end

    rt.viewid = out_viewid
    irq.update_rendertarget(rt)

    local ppinput = isys_properties.get "s_postprocess_input"
    ppinput.texture.handle = input

    irender.draw(out_viewid, pass.renderitem)
    return output
end

function pp_sys:combine_postprocess()
    local input = mainview_rbhandle
    reset_viewid_idx()
    for _, tech in iter_tech() do
        if tech then
            for _, pass in ipairs(tech) do
                input = render_pass(input, next_viewid(), pass)
            end
        end
    end
end

function ipp.main_rb_size(main_fbidx)
    if main_fbidx == nil then
        for e in w:select "main_queue render_target:in" do
            main_fbidx = e.render_target.fb_idx
            break
        end
    end

    local fb = fbmgr.get(main_fbidx)
    local rb = fbmgr.get_rb(fb[1])
    
    assert(rb.format:match "RGBA")
    return rb.w, rb.h
end

function ipp.get_rbhandle(fbidx, rbidx)
    local fb = fbmgr.get(fbidx)
    return fbmgr.get_rb(fb[rbidx]).handle
end

function ipp.techniques()
    return techniques
end

function  ipp.get_technique(techname)
    return techniques[techname]
end

function ipp.add_technique(name, tech)
    techniques[name] = tech
end

function ipp.create_pass(name, material, rt, transform, cameraeid)
    local eid = world:create_entity {
        policy = {"ant.render|simplerender"},
        data = {
            simplemesh  = ientity.quad_mesh(),
            material    = material,
            transform   = transform,
        }
    }

    return {
        name            = name,
        renderitem      = world[eid]._rendercache,
        render_target   = rt,
        camera_eid      = cameraeid,
        eid             = eid,
    }
end
