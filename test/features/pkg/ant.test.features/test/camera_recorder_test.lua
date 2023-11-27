local ecs = ...
local world = ecs.world
local w = world.w
local cr_test = ecs.system "camera_recorder_test_system"
local which_cr
local recording = false
local kb_mb = world:sub{"keyboard"}

local icr = ecs.require "ant.camera|camera_recorder"

function cr_test.data_changed()
    for _, code, press, state in kb_mb:unpack() do
        if code == "RETURN" and press == 0 then 
            recording = not recording
            if recording then
                which_cr = icr.start "test1"
            else
                icr.stop(which_cr)
            end
        elseif code == "SPACE" and press == 0 then
            for e in w:select "main_queue camera_ref:in" do
                icr.add(which_cr, e.camera_ref)
            end
        elseif state.CTRL and code == "P" and press == 0 then
            if recording then
                print("camera is recording, please stop before play")
            else
                for e in w:select "main_queue camera_ref:in" do
                    icr.play(which_cr, e.camera_ref)
                end
            end
        end
    end
end