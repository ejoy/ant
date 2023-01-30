local ecs = ...
local world = ecs.world
local w = world.w
local ui_rt_sys = ecs.system "ui_rt_system"

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
--[[ 
local kb_mb = world:sub{"keyboard"}
local ientity   = ecs.import.interface "ant.render|ientity"
local imaterial = ecs.import.interface "ant.asset|imaterial"
local math3d = require "math3d"

function ui_rt_sys:data_changed()
    for _, key, press in kb_mb:unpack() do
        if key == "T" and press == 0 then
            local gid = iUiRt.get_group_id("rt1")
            local g = ecs.group(gid)
            g:create_entity{
                policy = {
                    "ant.render|simplerender",
                    "ant.general|name",
                },
                data = {
                    simplemesh = ientity.arrow_mesh(0.3),
                    material = "/pkg/ant.resources/materials/meshcolor.material",
                    visible_state = "main_view",
                    scene = {

                    },
                    name = "arrow",
                    on_ready = function (ee)
                        imaterial.set_property(ee, "u_color", math3d.vector(1.0, 0.0, 0.0, 1.0))
                    end
                }
            }
        end
    end
end  ]]

