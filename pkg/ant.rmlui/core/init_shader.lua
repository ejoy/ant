local ltask = require "ltask"

local shaders <const> = {
    font            = "/pkg/ant.rmlui/materials/font.material",
    font_cr         = "/pkg/ant.rmlui/materials/font_cr.material",
    font_outline    = "/pkg/ant.rmlui/materials/font_outline.material",
    font_outline_cr = "/pkg/ant.rmlui/materials/font_outline_cr.material",
    font_shadow     = "/pkg/ant.rmlui/materials/font_shadow.material",
    font_shadow_cr  = "/pkg/ant.rmlui/materials/font_shadow_cr.material",
    image           = "/pkg/ant.rmlui/materials/image.material",
    image_cr        = "/pkg/ant.rmlui/materials/image_cr.material",
    image_gray      = "/pkg/ant.rmlui/materials/image_gray.material",
    image_cr_gray   = "/pkg/ant.rmlui/materials/image_cr.material",
    debug_draw      = "/pkg/ant.rmlui/materials/debug_draw.material",
}

local ServiceResource = ltask.uniqueservice "ant.resource_manager|resource"
local progs = {}
local uniforms = {}
local tasks = {}

for k, v in pairs(shaders) do
    tasks[#tasks+1] = {function ()
        local shader = ltask.call(ServiceResource, "material_create", v)
        for name, u in pairs(shader.fx.uniforms) do
            local handle = u.handle & 0xFFFF
            assert(uniforms[name] == handle or uniforms[name] == nil)
            uniforms[name] = handle
        end
        progs[k] = shader.fx.prog
    end}
end
for _ in ltask.parallel(tasks) do
end
progs.uniforms = uniforms
return progs
