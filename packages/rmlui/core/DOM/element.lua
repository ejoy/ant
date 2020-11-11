local event = require "core.event"
local mt = {}

local function constructor(document, handle)
    local o = {
        _handle = handle,
        ownerDocument = document,
    }
    return setmetatable(o, mt)
end

local pool = {}

function event.OnDeleteDocument(handle)
    pool[handle] = nil
end

return function (document, handle)
    if handle == nil then
        return
    end
    local _pool = pool[document._handle]
    if not _pool then
        _pool = {}
        pool[document._handle] = _pool
    end
    local o = _pool[handle]
    if not o then
        o = constructor(document, handle)
        _pool[handle] = {}
    end
    return o
end
