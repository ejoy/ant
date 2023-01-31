local ecs = ...
local world = ecs.world
local w = world.w

local iUiRt     = ecs.import.interface "ant.rmlui|iuirt"
local init_sys   = ecs.system "init_system"
local iRmlUi     = ecs.import.interface "ant.rmlui|irmlui"
local ivs		= ecs.import.interface "ant.scene|ivisible_state"
local function getArguments()
    return ecs.world.args.ecs.args
end

function init_sys:post_init()
    local args = getArguments()
    iRmlUi.add_bundle "/rml.bundle"
    iRmlUi.set_prefix "/resource"
    local window = iRmlUi.open(args[1])
    window.addEventListener("message", function (event)
        print("Message: " .. event.data)
    end)
end

local kb_mb = world:sub{"keyboard"}
local math3d        = require "math3d"
local ientity       = ecs.import.interface "ant.render|ientity"
local imaterial     = ecs.import.interface "ant.asset|imaterial"
function init_sys:data_changed()
    for _, key, press in kb_mb:unpack() do
        -- "rt1"对应.rml文件中<>里的名字
        -- 调用接口get_group_id("rt1")获取对应的group id创建该render target中的需要渲染的内容
        -- visible state需要由"rt1"衍生-->"rt1_queue"
        local gid = iUiRt.get_group_id("rt1")
        local g = ecs.group(gid)
        local queuename = "rt1".."_queue"
        if key == "T" and press == 0 then
            g:enable "view_visible"
            g:enable "scene_update"
--[[             local p = g:create_instance("/pkg/ant.resources/glb/Duck.glb|mesh.prefab")

            p.on_ready = function (e)
                for _, eid in ipairs(e.tag['*']) do
                    local ee = w:entity(eid, "visible_state?in")
                    if ee.visible_state then
                        ivs.set_state(ee, "rt1_queue", true)
                    end     
                end        
            end
            world:create_object(p)  ]]
            ecs.create_entity{
                policy = {
                    "ant.render|simplerender",
                    "ant.general|name",
                },
                data = {
                    simplemesh = ientity.arrow_mesh(10),
                    material = "/pkg/ant.resources/materials/meshcolor.material",
                    visible_state = queuename,
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
end


