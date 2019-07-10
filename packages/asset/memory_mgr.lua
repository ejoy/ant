local mgr = {}; 
mgr.__index = mgr

local resources = {}
function mgr.mark(restype, sizebytes, resinfo)
    local res = resources[restype] 
    if res == nil then
        res = {sizebytes=0}
        resources[restype] = res
    end

    res.sizebytes = res.sizebytes + sizebytes
    res.info = {sizebytes=sizebytes, resinfo=resinfo}
end

function mgr.tell_size(restype)
    local res = resources[restype]
    if res then
        return res.sizebytes
    end
end


return mgr