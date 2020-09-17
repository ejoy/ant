local ecs = ...
local world = ecs.world

local cr_test = ecs.system "camera_recorder_test_system"
local which_cr
local recording = false
local kb_mb = world:sub{"keyboard"}

local icr = world:interface "ant.camera|icamera_recorder"
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
            local ceid = world:singleton_entity "main_queue".camera_eid
            icr.add(which_cr, ceid)
        elseif state.CTRL and code == "P" and press == 0 then
            if recording then
                print("camera is recording, please stop before play")
            else
                local ceid = world:singleton_entity "main_queue".camera_eid
                icr.play(which_cr, ceid)
            end
        end
    end
end