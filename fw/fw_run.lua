return function(file_path, ...)
    if RUN_FUNC_NAME == file_path then
        pcall(RUN_FUNC, ...)
        return
    end

    local run_func, err = ant_load(file_path)
    if not run_func then
        perror(err)
        return nil
    end

    local err, result = pcall(run_func, ...)
    if not err then
        print("run file "..file_path.." error: " .. tostring(result))
        perror(result)
        return nil
    end

    RUN_FUNC_NAME = file_path
    RUN_FUNC = result
    pcall(RUN_FUNC, ...)
end