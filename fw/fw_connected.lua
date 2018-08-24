local Dbg = require 'debugger'
local DbgIO = {}
function DbgIO:event_in(f)
    RegisterIOCommand("dbg", function(data_table)
        f(data_table[2])
    end)
end
function DbgIO:update()
end
function DbgIO:send(data)
    SendIORequest({"dbg", data})
end
function DbgIO:close()
end
local DbgMaster = Dbg.start_master(DbgIO)
local DbgWorker = Dbg.start_worker()

function DbgUpdate()
    DbgMaster()
    DbgWorker()
end

function HandleMsg()
    while true do
        local key, value = linda:receive(0.001, table.unpack(IoCommand_name))
        if key then
            --run io function
            IoCommand_func[key](value)
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
