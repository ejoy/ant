local ecs = ...
local world = ecs.world

local fs = require "filesystem"

local assetpkg = import_package "ant.asset"
local assetmgr = assetpkg.mgr

local mathpkg  = import_package "ant.math"
local mu       = mathpkg.util

local fbmgr     = require "framebuffer_mgr"
local viewidmgr = require "viewid_mgr"
local renderutil= require "util"
local computil  = require "components.util"
local uniformuitl=require "uniforms"

local pps = ecs.component "postprocess_slot"
    .fb_idx         "fb_index"
    ["opt"].rb_idx  "rb_index"

function pps:init()
    self.rb_idx = self.rb_idx or 1
    return self
end

ecs.component_alias("postprocess_input",    "postprocess_slot")
ecs.component_alias("postprocess_output",   "postprocess_slot")

ecs.component "pass"
    .name           "string" ("")
    .material       "material"
    .viewport       "viewport"
    ["opt"].input   "postprocess_input"
    .output         "postprocess_output"

ecs.component "technique" {multiple=true}
    .name           "string"
    .passes         "pass[]"
    ["opt"].reorders"int[]"

ecs.component "technique_order"
    .orders "string[]"

ecs.component_alias("copy_pass", "pass")

local pp = ecs.singleton "postprocess"
function pp.init()
    return {
        techniques = {}
    }
end

local pp_sys = ecs.system "postprocess_system"
pp_sys.singleton "render_properties"
pp_sys.singleton "postprocess"

-- we list all postporcess effect here, but the order is dependent on effect's depend
pp_sys.depend "bloom_system"
pp_sys.depend "tonemapping"

pp_sys.depend "render_system"
pp_sys.dependby "end_frame"

local quad_reskey = fs.path "//res.mesh/postprocess.mesh"

local function alloc_range_viewids(num)
    local viewids = {}
    local name = "postprocess"
    for i=1, num do
        viewids[#viewids+1] = viewidmgr.generate(name .. i)
    end
    return viewids
end

local postprocess_viewids = alloc_range_viewids(30)

local viewid_idx = 0
local function next_viewid()
    viewid_idx = viewid_idx + 1
    return postprocess_viewids[viewid_idx]
end

local function reset_viewid_idx()
    viewid_idx = 0
end

function pp_sys:init()
    quad_reskey = assetmgr.register_resource(quad_reskey, computil.quad_mesh{x=-1, y=-1, w=2, h=2})
end

local function is_slot_equal(lhs, rhs)
    return lhs.fb_idx == rhs.fb_idx and lhs.rb_idx == rhs.rb_idx
end

local function render_pass(lastslot, out_viewid, pass, meshgroup, render_properties)
    local ppinput_stage = uniformuitl.system_uniform("s_postprocess_input").stage

    local in_slot = pass.input or lastslot
    local out_slot = pass.output
    if is_slot_equal(in_slot, out_slot) then
        error(string.format("input viewid[%d:%d] is the same as output viewid[%d:%d]", 
            in_slot.viewid, in_slot.slot, out_slot.viewid, out_slot.slot))
    end

    local function bind_input(slot)
        local pp_properties = render_properties.postprocess
        local fb = fbmgr.get(slot.fb_idx)
        pp_properties.textures["s_postprocess_input"] = {
            type = "texture", stage = ppinput_stage,
            name = "post process input frame buffer",
            handle = fbmgr.get_rb(fb[slot.rb_idx]).handle,
        }
        pp_properties.uniforms["u_bright_threshold"] = {
            type = "v4", name = "bright threshold",
            value = {0.8, 0.0, 0.0, 0.0}
        }
    end
    bind_input(in_slot)

    renderutil.update_frame_buffer_view(out_viewid, out_slot.fb_idx)
    renderutil.update_viewport(out_viewid, pass.viewport)

    renderutil.draw_primitive(out_viewid, {
        mgroup 	    = meshgroup,
        material 	= assert(assetmgr.get_resource(pass.material.ref_path)),
        properties  = pass.material.properties,
    }, mu.IDENTITY_MAT, render_properties)

    return out_slot
end

local function render_technique(tech, lastslot, meshgroup, render_properties)
    if tech.reorders then
        for _, passidx in ipairs(tech.reorders) do
            lastslot = render_pass(lastslot, next_viewid(), assert(tech.passes[passidx]), meshgroup, render_properties)
        end
    else
        for _, pass in ipairs(tech.passes) do
            lastslot = render_pass(lastslot, next_viewid(), pass, meshgroup, render_properties)
        end
    end

    return lastslot
end

function pp_sys:update()
    local pp = self.postprocess
    local techniques = pp.techniques
    if next(techniques) then
        local render_properties = self.render_properties
        local lastslot = {
            fb_idx = fbmgr.get_fb_idx(viewidmgr.get "main_view"),
            rb_idx = 1
        }
        
        local meshres = assetmgr.get_resource(quad_reskey)
        local meshgroup = meshres.scenes[1][1][1]

        reset_viewid_idx()
        for i=1, #techniques do
            local tech = techniques[i]
            lastslot = render_technique(tech, lastslot, meshgroup, render_properties)
        end
    end
end
