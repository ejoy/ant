local caches = {
    swap = function (self)
        if self.current == self[1] then
            self.current = self[2]
        else
            self.current = self[1]
        end
    end,
}

local c = {}
function c:check_add_cache(eid)
    local c = self[eid]
    if  c == nil then
        c = {}
        self[eid] = c
    end
    return c
end

function c:cache(eid, what, value)
    self[eid][what] = value
end

function c:get(eid, what)
    local c = self[eid]
    if c then
        return c[what]
    end
end

local function create()
    return setmetatable({}, {__index = c})
end

caches[1] = create()
caches[2] = create()

caches.current = caches[1]
return caches