return function()
    if entrance then
        local res = safe_run(entrance.terminate, "entrance.terminate")
        if not res then
            entrance = nil
        end
    end
end
