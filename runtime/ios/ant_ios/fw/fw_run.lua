return function(file_path, ...)
   if RUN_FUNC_NAME == file_path then
       pcall(RUN_FUNC, ...)
       return
   end

   local f, hash = io.open(file_path, "r")
   if not f then
       assert(false, "cannot find file: " .. file_path)
   end

    local content = f:read("a")
    f:close()

    local run_func, err_msg = load(content)
    if not run_func then
        perror(err_msg)
        error(err_msg)
    end
    
    local err, result = xpcall(run_func, debug.traceback, ...)
    if not err then
        print("run file "..file_path.." error: " .. tostring(result))
        perror(result)
    end

    RUN_FUNC_NAME = file_path
    RUN_FUNC = result
    pcall(RUN_FUNC, ...)
end