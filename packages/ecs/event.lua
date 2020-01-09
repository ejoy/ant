local NOTCARE      <const> = {}
local INDEX        <const> = {1,2}
local pairs        <const> = pairs
local setmetatable <const> = setmetatable
local table_unpack <const> = table.unpack

local function copytable(t)
    local r = {}
    for k, v in pairs(t) do
        r[k] = v
    end
    return r
end

local function compile_pattern(pattern)
    local res = {}
    for k, v in pairs(pattern) do
        res[#res+1] = k
        res[#res+1] = v
    end
    if #res == 0 then
        return false
    end
    return res
end

local function msg_match(message, compiled)
    for i = 1, #compiled, 2 do
        local k, v = compiled[i], compiled[i+1]
        if message[k] ~= v then
            return
        end
    end
    return true
end

local function msg_push(message, lst)
    if lst then
        for mb, compiled in pairs(lst) do
            if not compiled or msg_match(message, compiled) then
                mb[#mb+1] = message
            end
        end
    end
end

local mailbox = {}
mailbox.__index = mailbox

local function next_each(mb)
    local head = mb[1]
    local msg = mb[head]
    if msg then
        mb[head] = false
        mb[1] = head + 1
        return msg
    end
    mb[1] = 2
    for i = 2, #mb do
        mb[i] = nil
    end
end

function mailbox:each()
    return next_each, self
end

local function next_unpack(mb)
    local head = mb[1]
    local msg = mb[head]
    if msg then
        mb[head] = false
        mb[1] = head + 1
        return table_unpack(msg)
    end
    mb[1] = 2
    for i = 2, #mb do
        mb[i] = nil
    end
end

function mailbox:unpack()
    return next_unpack, self
end

local world = {}

function world:init()
    self._event_lookup = {}
    self._event_pattern = {}
end

function world:sub(pattern)
    local mb = setmetatable({2}, mailbox)
    local lookup = self._event_lookup
    self._event_pattern[mb] = copytable(pattern)
    for i = 1, #INDEX do
        local k = INDEX[i]
        local v = pattern[k]
        if not v then
            if lookup[NOTCARE] then
                lookup[NOTCARE][mb] = compile_pattern(pattern)
            else
                lookup[NOTCARE] = {[mb] = compile_pattern(pattern)}
            end
            return mb
        end
        pattern[k] = nil
        if not lookup[v] then
            lookup[v] = {}
        end
        lookup = lookup[v]
    end
    lookup[mb] = compile_pattern(pattern)
    return mb
end

function world:unsub(mb)
    local lookup = self._event_lookup
    local pattern = self._event_pattern[mb]
    for i = 1, #INDEX do
        local k = INDEX[i]
        local v = pattern[k]
        if not v then
            self._event_pattern[mb] = nil
            lookup[NOTCARE][mb] = nil
            return
        end
        lookup = lookup[v]
    end
    self._event_pattern[mb] = nil
    lookup[mb] = nil
end

function world:pub(message)
    local lookup = self._event_lookup
    for i = 1, #INDEX do
        local k = INDEX[i]
        local v = message[k]
        if not v or not lookup[v] then
            msg_push(message, lookup[NOTCARE])
            return
        end
        lookup = lookup[v]
    end
    msg_push(message, lookup)
end

return world
