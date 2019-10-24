local ecs = ...
local world = ecs.world

local fs = require "filesystem"

local assetpkg = import_package "ant.asset"
local assetmgr = assetpkg.mgr

local viewidmgr = require "viewid_mgr"
local fbmgr     = require "framebuffer_mgr"
local renderutil= require "render.util"
local computil  = require "components.util"

ecs.tag "postprocess"
ecs.component_alias("postprocess_input",    "viewid")
ecs.component_alias("postprocess_output",   "viewid")

local pass = ecs.component "pass"
    .name       "string" ("")
    .viewidname "string"
    .material   "material"
    .input      "postprocess_input"
    .output     "postprocess_output"

function pass:init()
    self.viewid = viewidmgr.get(self.viewidname)
    return self
end

local technique = ecs.component "technique" {multiple=true}
    .name        "string"
    .passes      "pass[]"
    ["opt"].reorders    "int[]"

function technique:init()

end

local pp_sys = ecs.system "postprocess_system"
pp_sys.singleton "render_properties"
pp_sys.depend "render_system"
pp_sys.depend "bloom_system"

local quad_reskey = fs.path "//meshres/postprocess.mesh" 

function pp_sys:init()
    quad_reskey = assetmgr.register_resource(quad_reskey, computil.quad_mesh{x=0, y=0, w=1, h=1})

    world:create_entity {
        technique = {
            passes = {}
        },
        postprocess = true,
    }
end

local function render_pass(pass, render_properties)
    local function bind_input(in_viewid)
        local pp_properties = render_properties.postprocess
        local fb = fbmgr.get(in_viewid)
        pp_properties["postprocess_input"] = {
            type = "texture", stage = 0,
            name = "post process output frame buffer",
            handle = fb.render_buffers[1].handle,
        }
    end
    bind_input(pass.input)

    local meshres = assetmgr.load(quad_reskey)
    local group = meshres.scenes[1][1][1]
    renderutil.draw_primitive(pass.output, group, nil, render_properties)
end

function pp_sys:init()
    local pp = world:first_entity "postprocess"
    local techniques = pp.techniques
    local render_properties = self.render_properties
    for tech in world:each_component(techniques) do
        if tech.reorders then
            for _, idx in ipairs(tech.reorders) do
                local pass = assert(tech.passes[idx])
                render_pass(pass, render_properties)
            end
        else
            for _, pass in ipairs(tech.passes) do
                render_pass(pass, render_properties)
            end
        end
    end
end
