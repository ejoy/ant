local function stopOnEntry()
    for _, v in ipairs(arg) do
        if v == '-stopOnEntry' then
            return true
        end
    end
    return false
end

local dbg = dofile "engine/firmware/debugger.lua"
    : start {}

if stopOnEntry() then
    dbg:event "wait"
end
