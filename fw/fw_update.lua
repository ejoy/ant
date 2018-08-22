return function()

    if entrance then
        local ml_res , err_string = pcall(entrance.mainloop)
        if not ml_res then
            print("entrance update error", err_string)
            entrance = nil
        end
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