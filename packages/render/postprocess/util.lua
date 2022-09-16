local ecs = ...

local irender = ecs.import.interface "ant.render|irender"

local util = {}
function util.create_quad_drawer(tab, material)
    return ecs.create_entity{
        policy = {
            "ant.render|simplerender",
            "ant.general|name",
        },
        data = {
            name = tab,
            simplemesh = irender.full_quad(),
            material = material,
            visible_state = "",
            scene = {},
            [tab] = true,
        }
    }
end

function util.create_queue(viewid, vr, fbidx, queuename, tabname)
    local template = {
        policy = {
            "ant.render|postprocess_queue",
            "ant.general|name",
        },
        data = {
            render_target = {
                view_rect = vr,
                view_mode = "",
                clear_state = {clear=""},
                viewid = viewid,
                fb_idx = fbidx,
            },
            [queuename] = true,
            queue_name = queuename,
            name = queuename,
        }
    }

    if tabname then
        template.data[tabname] = true
    end
    ecs.create_entity(template)
end

return util