local dbg = import_package 'ant.debugger'

local function stopOnEntry()
    for _, v in ipairs(arg) do
        if v == '-stopOnEntry' then
            return true
        end
    end
    return false
end

return dbg.start(stopOnEntry())
