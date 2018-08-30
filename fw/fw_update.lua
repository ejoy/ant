
local DbgWorker = require 'debugger'.start_worker()

return function()
    if DbgWorker then
        DbgWorker()
    end

    if entrance then
        local res = safe_run(entrance.mainloop, "entrance.mainloop")
        if not res then
            --try properly terminate it
            safe_run(entrance.terminate, "entrance.terminate")
            entrance = nil
        end
        --entrance.mainloop()
        --[[
        local log = bgfx.get_log()
        if log and #log>0 then
            print("get bgfx log")
            print(log)
        end
        --]]
    end

    HandleMsg()
    HandleCacheScreenShot()
end