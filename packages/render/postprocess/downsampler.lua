local ecs   = ...
local world = ecs.world
local w     = world.w

local fbmgr     = require "framebuffer_mgr"

local bgfx      = require "bgfx"

local irender   = ecs.import.interface "ant.render|irender"
local imesh     = ecs.import.interface "ant.asset|imesh"
local imaterial = ecs.import.interface "ant.asset|imaterial"
local ientity   = ecs.import.interface "ant.render|ientity"
local ds_sys    = ecs.system "downsample_system"

function ds_sys:init()
    ecs.create_entity{
        policy = {
            "ant.general|name",
            "ant.render|simplerender",
        },
        data = {
            downsample_drawer = true,
            scene 		= {srt={}},
            simplemesh  = imesh.init_mesh(ientity.fullquad_mesh()),
            material    = "/pkg/ant.resources/materials/downsample.material",
            filter_state= "main_view",
            name        = "downsample",
        }
    }
end

local ids = ecs.interface "idownsampler"

function ids.set_targets(targets)
    for i=1, #targets do
        local target = targets[i]
        local viewid = target.viewid

        bgfx.set_view_rect(viewid, target.view_rect)

        if target.clear_state then
            bgfx.set_view_clear_state(viewid, target.clear_state)
        end
        
        if target.fb_idx then
            local fb = fbmgr.get(target.fb_idx)
            bgfx.set_view_frame_buffer(viewid, fb.handle)
        end

        if target.view_mode then
            bgfx.set_view_mode(viewid, target.view_mode)
        end
    end
end

local input0 = {
    stage = 0,
    texture = {handle=nil}
}

function ids.downsample(targets)
    local drawer = w:singleton("downsample_drawer", "render_object:in")
    local ro = drawer.render_object

    for i=1, #targets do
        local target = targets[i]
        local viewid = target.viewid
        input0.texture.handle = target.handle
        imaterial.set_property_directly(ro.properties, "s_scene_color", input0)
        irender.draw(viewid, ro)
    end

end