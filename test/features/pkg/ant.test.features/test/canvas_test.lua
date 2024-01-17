local ecs   = ...
local world = ecs.world
local w     = world.w

local common = ecs.require "common"
local util  = ecs.require "util"
local PC    = util.proxy_creator()

local ct_sys = common.test_system "canvas"
local icanvas = ecs.require "ant.terrain|canvas"

local canvas_eid
function ct_sys.init_world()
    canvas_eid = PC:create_entity {
        policy = {
            "ant.scene|scene_object",
            "ant.terrain|canvas",
        },
        data = {
            scene = {
                t = {0.0, 2, 0.0},
            },
            canvas = {
                show = true,
            },
        }
    }
end

local kb_mb = world:sub {"keyboard"}
local itemsids = nil

function ct_sys.data_changed()
    for _, key, press in kb_mb:unpack() do
        if key == "C" and press == 0 then
            if itemsids then
                icanvas.show(world:entity(canvas_eid), false)
                icanvas.remove_item(world:entity(canvas_eid), itemsids[1])
                itemsids = nil
                return
            end
            itemsids = icanvas.add_items(world:entity(canvas_eid), "/pkg/ant.test.features/assets/canvas_texture.material", "background",
            {
                x = 2, y = 2, w = 4, h = 4,
                texture = {
                    rect = {
                        x = 0, y = 0,
                        w = 32, h = 32,
                    },
                },
            },
            {
                x = 0, y = 0, w = 2, h = 2,
                texture = {
                    rect = {
                        x = 32, y = 32,
                        w = 32, h = 32,
                    },
                },
            })

        end
    end
end

function ct_sys:exit()
    if canvas_eid and itemsids then
        for _, id in ipairs(itemsids) do
            local e<close> = world:entity(canvas_eid)
            icanvas.remove_item(e, id)
        end
    end

    PC:clear()
end