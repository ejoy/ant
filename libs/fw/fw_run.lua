return function(file_path, ...)
    if RUN_FUNC_NAME == file_path then
        pcall(RUN_FUNC, ...)
        return
    end

    local run_func, err = ant_load(file_path)
    if not run_func then
        perror(err)
        error(err)
        return nil
    end

    local err, result = pcall(run_func, ...)
    --print("run func", g_WindowHandle, g_Width, g_Height)

    if not err then
        perror(result)
        error(result)
        return
    end

    RUN_FUNC_NAME = file_path
    RUN_FUNC = result
    print("start run func: "..file_path, result)
    if type(result) == "table" then
        for k, v in pairs(result) do
            print(k, v)
        end
    end
    local res, err = xpcall(RUN_FUNC, debug.traceback, ...)
    print("run func: "..file_path .. " result ", res, err)
end
