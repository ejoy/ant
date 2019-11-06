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

ecs.tag "postprocess"
local pps = ecs.component "postprocess_slot"
    .viewid "viewid"
    ["opt"].slot   "int"

function pps:init()
    self.slot = self.slot or 1
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

local pp_sys = ecs.system "postprocess_system"
pp_sys.singleton "render_properties"

-- we list all postporcess effect here, but the order is dependent on effect's depend
pp_sys.depend "bloom_system"
pp_sys.depend "tonemapping"

pp_sys.depend "render_system"
pp_sys.dependby "end_frame"

local quad_reskey = fs.path "//meshres/postprocess.mesh"

function pp_sys:init()
    quad_reskey = assetmgr.register_resource(quad_reskey, computil.quad_mesh{x=0, y=0, w=1, h=1})

    world:create_entity {
        postprocess = true,
    }
end

local function is_slot_equal(lhs, rhs)
    return lhs.viewid == rhs.viewid and lhs.slot == rhs.slot
end

local function render_pass(lastslot, pass, meshgroup, render_properties)
    local ppinput_stage = uniformuitl.system_uniform("s_postprocess_input").stage

    local in_slot = pass.input or lastslot
    local out_slot = pass.output
    if is_slot_equal(in_slot, out_slot) then
        error(string.format("input viewid[%d:%d] is the same as output viewid[%d:%d]", 
            in_slot.viewid, in_slot.slot, out_slot.viewid, out_slot.slot))
    end

    local function bind_input(in_viewid, slot)
        local pp_properties = render_properties.postprocess
        local fb = fbmgr.get_byviewid(in_viewid)
        pp_properties.textures["s_postprocess_input"] = {
            type = "texture", stage = ppinput_stage,
            name = "post process input frame buffer",
            handle = fbmgr.get_rb(fb[slot]).handle,
        }
        pp_properties.uniforms["u_bright_threshold"] = {
            type = "v4", name = "bright threshold",
            value = {0.85, 0.0, 0.0, 0.0}
        }
    end
    bind_input(in_slot.viewid, in_slot.slot)

    local out_viewid = out_slot.viewid
    renderutil.update_frame_buffer_view(out_viewid)
    renderutil.update_viewport(out_viewid, pass.viewport)

    renderutil.draw_primitive(out_viewid, {
        mgroup 	    = meshgroup,
        material 	= assert(assetmgr.get_resource(pass.material.ref_path)),
        properties  = pass.material.properties,
    }, mu.IDENTITY_MAT, render_properties)

    return { viewid=out_viewid, slot=1} --right now, output slot only 1
end

local function render_technique(tech, lastslot, meshgroup, render_properties)
    if tech.reorders then
        for _, idx in ipairs(tech.reorders) do
            local pass = assert(tech.passes[idx])
            lastslot = render_pass(lastslot, pass, meshgroup, render_properties)
        end
    else
        for _, pass in ipairs(tech.passes) do
            lastslot = render_pass(lastslot, pass, meshgroup, render_properties)
        end
    end

    return lastslot
end

function pp_sys:update()
    local pp = world:first_entity "postprocess"
    local technique = pp.technique
    local render_properties = self.render_properties
    local lastslot = {
        viewid = viewidmgr.get "main_view",
        slot = 1
    }
    
    local meshres = assetmgr.load(quad_reskey)
    local meshgroup = meshres.scenes[1][1][1]

    for _, tech in world:each_component(technique) do
        lastslot = render_technique(tech, lastslot, meshgroup, render_properties)
    end
end
