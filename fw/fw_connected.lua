
--remote code can be put blow here
local dbg = require("debugger")
--dbg.start_worker()

local bgfx = require "bgfx"
local screenshot_cache_num = 0
function HandleMsg()
    while true do
        local key, value = linda:receive(0.001, "run", "screenshot_req")
        if key == "run" then
            --server may modified files, need changeroot

            run(value)
        elseif key == "screenshot_req" then
            if entrance then
                bgfx.request_screenshot()
                screenshot_cache_num = screenshot_cache_num + 1
                print("request screenshot: ".. value[2].." num: "..screenshot_cache_num)
            end
        else
            break
        end
    end
end

function HandleCacheScreenShot()
    --if screenshot_cache_num
    --for i = 1, screenshot_cache_num do
    if screenshot_cache_num > 0 then
        local name, width, height, pitch, data = bgfx.get_screenshot()
        if name then
            local size =#data
            print("screenshot size is "..size)
            screenshot_cache_num = screenshot_cache_num - 1
            --compress to png format
            --default is bgra format
            local data_string = lodepng.encode_png(data, width, height);
            print("screenshot encode size ",#data_string)
            linda:send("screenshot", {name, data_string})
        end
    end
end
