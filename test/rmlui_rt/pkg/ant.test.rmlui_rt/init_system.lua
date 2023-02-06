local ecs = ...
local world = ecs.world
local w = world.w

local iUiRt     = ecs.import.interface "ant.rmlui|iuirt"
local init_sys   = ecs.system "init_system"
local iRmlUi     = ecs.import.interface "ant.rmlui|irmlui"
local ivs		= ecs.import.interface "ant.scene|ivisible_state"
local kb_mb = world:sub{"keyboard"}
local function getArguments()
    return ecs.world.args.ecs.args
end

function init_sys:init()
    local gid = iUiRt.get_group_id("rt1")
    local g = ecs.group(gid)
    local p1 = g:create_instance "pkg/ant.resources/glb/light.prefab"
    p1.on_ready = function (e)
        for _, eid in ipairs(e.tag['*']) do
            local ee = w:entity(eid, "visible_state?in")
            if ee.visible_state then
                ivs.set_state(ee, "rt1_queue", true)
            end     
        end        
    end
    world:create_object(p1)
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

local math3d        = require "math3d"
local ientity       = ecs.import.interface "ant.render|ientity"
local imaterial     = ecs.import.interface "ant.asset|imaterial"
local iom           = ecs.import.interface "ant.objcontroller|iobj_motion"
function init_sys:entity_init()
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

            local p1 = g:create_instance("/pkg/ant.resources/glb/Duck.glb|mesh.prefab")
            p1.on_ready = function (e)
                for _, eid in ipairs(e.tag['*']) do
                    local ee = w:entity(eid, "visible_state?in")
                    if ee.visible_state then
                        ivs.set_state(ee, "main_view|selectable|cast_shadow", false)
                        ivs.set_state(ee, "rt1_queue", true)
                        iom.set_position(ee, math3d.vector(0, 0, 0))
                    end     
                end        
            end            
            world:create_object(p1) 

--[[             local p2 = g:create_entity {
                policy = {
                    "ant.render|render",
                    "ant.general|name",
                },
                data = {
                    name        = "test_sphere",
                    scene  = {s = 1, t = {0, 0, 0}},
                    material    = "/pkg/ant.resources/materials/pbr_default.material",
                    visible_state = "rt1_queue",
                    mesh        = "/pkg/ant.resources.binary/meshes/base/sphere.glb|meshes/Sphere_P1.meshbin",
                },
            }   ]]          
        end
    end
end


