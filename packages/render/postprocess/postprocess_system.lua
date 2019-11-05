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
ecs.component_alias("postprocess_input",    "viewid")
ecs.component_alias("postprocess_output",   "viewid")

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
pp_sys.depend "render_system"
pp_sys.dependby "end_frame"

local quad_reskey = fs.path "//meshres/postprocess.mesh"

function pp_sys:init()
    quad_reskey = assetmgr.register_resource(quad_reskey, computil.quad_mesh{x=0, y=0, w=1, h=1})

    world:create_entity {
        postprocess = true,
    }
end

local function render_pass(lastviewid, pass, meshgroup, render_properties)
    local ppinput_stage = uniformuitl.system_uniform("s_postprocess_input").stage
    local function bind_input(in_viewid)
        local pp_properties = render_properties.postprocess
        local fb = fbmgr.get_byviewid(in_viewid)
        pp_properties.textures["s_postprocess_input"] = {
            type = "texture", stage = ppinput_stage,
            name = "post process input frame buffer",
            handle = fbmgr.get_rb(fb[1]).handle,
        }
    end
    
    local in_viewid = pass.input or lastviewid
    local out_viewid = pass.output
    if in_viewid == out_viewid then
        error(string.format("input viewid[%d] is the same as output viewid[%d]", in_viewid, out_viewid))
    end
    bind_input(in_viewid)

    renderutil.update_frame_buffer_view(out_viewid)
    renderutil.update_viewport(out_viewid, pass.viewport)

    renderutil.draw_primitive(out_viewid, {
        mgroup 	    = meshgroup,
        material 	= assert(assetmgr.get_resource(pass.material.ref_path)),
        properties  = pass.material.properties,
    }, mu.IDENTITY_MAT, render_properties)

    return out_viewid
end

local function render_technique(tech, lastviewid, meshgroup, render_properties)
    if tech.reorders then
        for _, idx in ipairs(tech.reorders) do
            local pass = assert(tech.passes[idx])
            lastviewid = render_pass(lastviewid, pass, meshgroup, render_properties)
        end
    else
        for _, pass in ipairs(tech.passes) do
            lastviewid = render_pass(lastviewid, pass, meshgroup, render_properties)
        end
    end

    return lastviewid
end

function pp_sys:update()
    local pp = world:first_entity "postprocess"
    local technique = pp.technique
    local render_properties = self.render_properties
    local lastviewid = viewidmgr.get "main_view"
    local meshres = assetmgr.load(quad_reskey)
    local meshgroup = meshres.scenes[1][1][1]

    for _, tech in world:each_component(technique) do
        render_technique(tech, lastviewid, meshgroup, render_properties)
    end
end
