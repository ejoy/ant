local ecs   = ...
local world = ecs.world
local w     = world.w

local ibs           = ecs.require "ant.render|blur_scene.blur_scene"

local bst_sys       = ecs.system "blur_scene_test_system"

local kb_mb         = world:sub{"keyboard"}

local function blur_scene_with_start_begin()
    ibs.blur_scene(2)
end

function bst_sys.ui_update()
    blur_scene_with_start_begin()
    for _, key, press in kb_mb:unpack() do
        if key == "A" and press == 0 then
            blur_scene_with_start_begin()
        elseif key == "A" and press == 0 then
            ibs.blur_scene()
        elseif key == "B" and press == 0 then
            ibs.restore_scene()
        end
    end
end