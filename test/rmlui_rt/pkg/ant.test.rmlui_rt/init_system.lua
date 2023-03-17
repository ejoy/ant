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
        local alleid = e.tag['*']
        local re <close> = w:entity(alleid[1])
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

            local ground = g:create_instance("/pkg/ant.resources/glb/plane.glb|mesh.prefab")
            ground.on_ready = function (e)
                local alleid = e.tag['*']
                local re <close> = w:entity(alleid[1])
                iom.set_scale(re, math3d.vector(10, 1, 10))
                for _, eid in ipairs(alleid) do
                    local ee <close> = w:entity(eid, "visible_state?in name:in")
                    if ee.visible_state then
                        ivs.set_state(ee, "main_view|selectable|cast_shadow", false)
                        ivs.set_state(ee, queuename, true)
                    end
                end
            end
            world:create_object(ground)  

            local p1 = g:create_instance("/pkg/ant.resources/glb/Duck.glb|mesh.prefab")
            
            p1.on_ready = function (e)
                local alleid = e.tag['*']
                local re <close> = w:entity(alleid[1])
                iom.set_position(re, math3d.vector(0, 0, 0))
                for _, eid in ipairs(e.tag['*']) do
                    local ee = w:entity(eid, "visible_state?in")
                    if ee.visible_state then
                        ivs.set_state(ee, "main_view|selectable|cast_shadow", false)
                        ivs.set_state(ee, "rt1_queue", true)
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

local mc 		= import_package "ant.math".constant


function init_sys:end_frame()
    if iUiRt.get_group_id("rt1") then
        local gid = iUiRt.get_group_id("rt1")
        local g = ecs.group(gid)
        g:enable "rt1_queue_visible"
        for ee in w:select "rt1_queue_visible bounding:in scene:in eid:in name?in" do
            if not ee then
                goto continue
            end
            if ee.name and ee.name == "Plane" or ee.name == "light" then
                goto continue
            end
            if ee.bounding.scene_aabb and ee.bounding.scene_aabb ~= mc.NULL then
                local aabb = ee.bounding.scene_aabb
                if aabb ~= mc.NULL then
                    iUiRt.calc_camera_t("rt1_queue", aabb) 
                end              
            end
            ::continue::
        end
        g:disable "rt1_queue_visible" 
    end  
end
