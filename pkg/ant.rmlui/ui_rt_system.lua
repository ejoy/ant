local ecs = ...
local world = ecs.world
local w = world.w
local ui_rt_sys = ecs.system "ui_rt_system"
local ivs		= ecs.import.interface "ant.scene|ivisible_state"
local ui_rt_group_id = 110000

local rt2g_table = {}
local g2rt_table = {}

local iUiRt = ecs.interface "iuirt"

function iUiRt.gen_group_id(name)
    local queuename = name.."_queue"
    local gid = ui_rt_group_id + 1
    ui_rt_group_id = gid
    rt2g_table[name] = gid
    g2rt_table[gid]  = name
    w:register{ name = name.."_obj"}
    w:register{ name = queuename}
    w:register{ name = queuename.."_cull"}
    w:register{ name = queuename.."_visible"}
end

function iUiRt.get_group_id(name)
    return rt2g_table[name]
end

function ui_rt_sys:entity_init()
    for gid, name in pairs(g2rt_table) do
        local g = ecs.group(gid)
        local obj = name.."_obj"
        local queue_visible = name.."_queue_visible"
        g:enable(obj)
        local s_select = ("%s%s%s"):format("INIT ", obj, " render_object")
        local s_visible = ("%s%s"):format(queue_visible, "?out")
        for e in w:select(s_select) do
            w:extend(e, s_visible)
            e[queue_visible] = true
        end        
    end
end
 
