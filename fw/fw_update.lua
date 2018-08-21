return function()

    if entrance then
        entrance.mainloop()
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