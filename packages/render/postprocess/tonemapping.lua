local ecs = ...
local world = ecs.world

local viewidmgr = require "viewid_mgr"
local fbmgr = require "framebuffer_mgr"
local fs = require "filesystem"

local tm = ecs.system "tonemapping"
tm.depend    "render_system"
tm.dependby  "postprocess_system"

function tm:post_init()
    local pp_eid = world:first_entity_eid "postprocess"
    local main_viewid = viewidmgr.get "main_view"

    local fbsize = world.args.fbsize
    world:add_component(pp_eid, "technique", {
        name = "tonemapping",
        passes = {
            {
                name = "main",
                material = fs.path "/pkg/ant.resources/depiction/materials/tonemapping/tonemapping.material",
                output = 1,
                render_target = {
                    viewport = {
                        rect = {x=0, y=0, w=fbsize.w, h=fbsize.h},
                        clear_state = {clear="C", color=0},
                    }
                }
            },

        },
    })
end