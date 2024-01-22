local ecs   = ...
local world = ecs.world
local w     = world.w

local ibs           = ecs.require "ant.render|blur_scene.blur_scene"
local util  = ecs.require "util"
local common = ecs.require "common"
local bst_sys = common.test_system "blur_scene"

local kb_mb         = world:sub{"keyboard"}

function bst_sys.ui_update()
    for _, key, press in kb_mb:unpack() do
        if key == "A" and press == 0 then
            ibs.blur_scene()
        elseif key == "B" and press == 0 then
            ibs.restore_scene()
        end
    end
end