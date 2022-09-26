local ecs = ...

local irender = ecs.import.interface "ant.render|irender"

local math3d = require "math3d"

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

-- estimate of the size in pixel of a 1m tall/wide object viewed from 1m away (i.e. at z=1)
function util.projection_scale(w, h, projmat)
    -- estimate of the size in pixel of a 1m tall/wide object viewed from 1m away (i.e. at z=1)
    local projmat_c1, projmat_c2 = math3d.index(projmat, 1, 2)
    local c1x, c2y = math3d.index(projmat_c1, 1), math3d.index(projmat_c2, 2)
    return math.min(c1x*0.5*w, c2y*0.5*h)
end

function util.reverse_depth_param(projmat)
    local pm_c3, pm_c4 = math3d.index(projmat, 3, 4)
    return math3d.index(pm_c3, 3), math3d.index(pm_c4, 3)
end

return util