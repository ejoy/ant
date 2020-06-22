local ecs = ...
local world = ecs.world

local mathpkg  = import_package "ant.math"
local mu       = mathpkg.util

local fbmgr     = require "framebuffer_mgr"
local viewidmgr = require "viewid_mgr"
local renderutil= require "util"
local isys_properties  = world:interface "ant.render|system_properties"
local computil = world:interface "ant.render|entity"

local pp_sys = ecs.system "postprocess_system"

local techniques = {}
local quad_mesh

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
    quad_mesh = computil.quad_mesh {x=-1, y=-1, w=2, h=2}
end

local function is_slot_equal(lhs, rhs)
    return lhs.fb_idx == rhs.fb_idx and lhs.rb_idx == rhs.rb_idx
end
local irender = world:interface "ant.render|irender"
local function render_pass(lastslot, out_viewid, pass, meshgroup)
    local ppinput = isys_properties.get "s_postprocess_input"

    local in_slot = pass.input or lastslot
    local out_slot = pass.output
    if is_slot_equal(in_slot, out_slot) then
        error(string.format("input viewid[%d:%d] is the same as output viewid[%d:%d]", 
            in_slot.viewid, in_slot.slot, out_slot.viewid, out_slot.slot))
    end

    local function bind_input(slot)
        local fb = fbmgr.get(slot.fb_idx)
        ppinput.texture.handle = fbmgr.get_rb(fb[slot.rb_idx]).handle
        render_properties["u_bright_threshold"] = {
            {0.8, 0.0, 0.0, 0.0}
        }
    end
    bind_input(in_slot)

    irender.update_frame_buffer_view(out_viewid, out_slot.fb_idx)
    irender.update_viewport(out_viewid, pass.viewport)

    local material = pass.material
    irender.draw(out_viewid, {
        ib = meshgroup.ib,
        vb = meshgroup.vb,
        fx  = material.fx,
        properties = material.properties,
        state = material._state,
    }, mu.IDENTITY_MAT)

    return out_slot
end

local function render_technique(tech, lastslot, meshgroup)
    if tech.reorders then
        for _, passidx in ipairs(tech.reorders) do
            lastslot = render_pass(lastslot, next_viewid(), assert(tech.passes[passidx]), meshgroup)
        end
    else
        for _, pass in ipairs(tech.passes) do
            lastslot = render_pass(lastslot, next_viewid(), pass, meshgroup)
        end
    end

    return lastslot
end

function pp_sys:combine_postprocess()
    if next(techniques) then
        local lastslot = {
            fb_idx = fbmgr.get_fb_idx(viewidmgr.get "main_view"),
            rb_idx = 1
        }

        reset_viewid_idx()
        for i=1, #techniques do
            local tech = techniques[i]
            lastslot = render_technique(tech, lastslot, quad_mesh)
        end
    end
end

local ipp = ecs.interface "postprocess"

function ipp.main_rb_size(main_fbidx)
    main_fbidx = main_fbidx or fbmgr.get_fb_idx(viewidmgr.get "main_view")

    local fb = fbmgr.get(main_fbidx)
    local rb = fbmgr.get_rb(fb[1])
    
    assert(rb.format:match "RGBA")
    return {w=rb.w, h=rb.h}
end

function ipp.techniques()
    return techniques
end
