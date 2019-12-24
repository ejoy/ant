local NOTCARE <const> = {}
local INDEX <const> = {1,2}

local function copytable(t)
    local r = {}
    for k, v in pairs(t) do
        r[k] = v
    end
    return r
end

local function addmb(lookup, mb)
    local pattern = copytable(mb.__pattern)
    for _, k in ipairs(INDEX) do
        local v = pattern[k]
        if not v then
            mb.__compiled = pattern
            if lookup[NOTCARE] then
                lookup[NOTCARE][mb] = true
            else
                lookup[NOTCARE] = {[mb] = true}
            end
            return
        end
        pattern[k] = nil
        if not lookup[v] then
            lookup[v] = {}
        end
        lookup = lookup[v]
    end
    mb.__compiled = pattern
    lookup[mb] = true
end

local function delmb(lookup, mb)
    local pattern = mb.__pattern
    for _, k in ipairs(INDEX) do
        local v = pattern[k]
        if not v then
            lookup[NOTCARE][mb] = nil
            return
        end
        lookup = lookup[v]
    end
    lookup[mb] = nil
end


local function filter(message, lst)
    local res = {}
    for mb in pairs(lst) do
        res[mb] = true
        for k, v in pairs(mb.__compiled) do
            if message[k] ~= v then
                res[mb] = nil
                break
            end
        end
    end
    return res
end

local function findmb(lookup, message)
    for _, k in ipairs(INDEX) do
        local v = message[k]
        if not v or not lookup[v] then
            return lookup[NOTCARE] and filter(message, lookup[NOTCARE]) or {}
        end
        lookup = lookup[v]
    end
    return lookup and filter(message, lookup) or {}
end

local mailbox = {}
mailbox.__index = mailbox

function mailbox:each()
    local q = self.__queue
    return function ()
        local msg = q[1]
        if msg then
            table.remove(q, 1)
            return msg
        end
    end
end

function mailbox:unpack()
    local q = self.__queue
    return function ()
        local msg = q[1]
        if msg then
            table.remove(q, 1)
            return table.unpack(msg)
        end
    end
end

function mailbox:each()
    local q = self.__queue
    return function ()
        local msg = q[1]
        if msg then
            table.remove(q, 1)
            return msg
        end
    end
end

function mailbox:unsub()
    delmb(self.__mgr, self)
end

local function create_mailbox(mgr, pattern)
    return setmetatable({
        __mgr = mgr,
        __pattern = pattern,
        __queue = {}
    }, mailbox)
end

local world = {}

function world:init()
    self._event_mgr = {}
end

function world:sub(pattern)
    local mgr = self._event_mgr
    local mb = create_mailbox(mgr, pattern)
    addmb(mgr, mb)
    return mb
end

function world:pub(message)
    local mgr = self._event_mgr
    for mb in pairs(findmb(mgr, message)) do
        local q = mb.__queue
        q[#q+1] = message
    end
end

return world
