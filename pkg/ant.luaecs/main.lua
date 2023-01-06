local ecs = require "ecs"

local function getM()
    local w = ecs.world()
    return debug.getmetatable(w)
end

local M = getM()
local context = setmetatable({}, {__mode="k"})

function M.visitor_create(w)
    local proxy_mt = {}
    function proxy_mt:__index(name)
        local eid = self.eid
        local t = w:access(eid, name)
        if type(t) ~= "table" or w:type(name) ~= "c" then
            return t
        end
        local mt = {}
        mt.__index = t
        function mt:__newindex(k, v)
            if t[k] ~= v then
                t[k] = v
                w:access(eid, name, t)
            end
        end
        return setmetatable({}, mt)
    end
    function proxy_mt:__newindex(name, value)
        w:access(self.eid, name, value)
    end
    local visitor = {}
    local visitor_mt = {}
    function visitor_mt:__index(eid)
        if not w:exist(eid) then
            return
        end
        local proxy = setmetatable({eid=eid}, proxy_mt)
        visitor[eid] = proxy
        return proxy
    end
    context[w] = visitor
    return setmetatable(visitor, visitor_mt)
end

function M.visitor_update(w)
    local visitor = context[w]
    for e in w:select "REMOVED eid:in" do
        visitor[e.eid] = nil
    end
end

function M.visitor_clear(w)
    local visitor = context[w]
    for eid in pairs(visitor) do
        visitor[eid] = nil
    end
end

local submit = setmetatable({}, {__mode="k", __index = function (t, w)
    local mt = {}
    function mt:__close()
        w:submit(self)
    end
    t[w] = mt
    return mt
end})

function M.entity(w, eid, pattern)
    local v = w:fetch(eid, pattern)
    if v then
        return setmetatable(v, submit[w])
    end
end

return ecs
