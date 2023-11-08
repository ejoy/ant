local ecs = ...
local world = ecs.world

local irender = ecs.require "ant.render|render_system.render"

local math3d = require "math3d"

local util = {}
function util.create_queue(viewid, vr, fbidx, queuename, tabname, autoresize)
    local template = {
        policy = {
            "ant.render|postprocess_queue",
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
            visible = true,
        }
    }

    if tabname then
        template.data[tabname] = true
    end

    if autoresize then
        template.policy[#template.policy+1] = "ant.render|watch_screen_buffer"
        template.data.watch_screen_buffer = true
    end
    world:create_entity(template)
end

-- estimate of the size in pixel of a 1m tall/wide object viewed from 1m away (i.e. at z=1)
function util.projection_scale(w, h, projmat)
    local projmat_c1, projmat_c2 = math3d.index(projmat, 1, 2)
    local c1x, c2y = math3d.index(projmat_c1, 1), math3d.index(projmat_c2, 2)
    return math.min(c1x*0.5*w, c2y*0.5*h)
end

function util.reverse_position_param(projmat)
    local pm_c1, pm_c2, pm_c3, pm_c4 = math3d.index(projmat, 1, 2, 3, 4)
    -- for depth reverse
    local A, B = math3d.index(pm_c3, 3), math3d.index(pm_c4, 3)
    -- for position X, Y reverse
    local X, Y = math3d.index(pm_c1, 1), math3d.index(pm_c2, 2)
    return X, Y, A, B
    
end

return util