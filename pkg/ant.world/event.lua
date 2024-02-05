local NOTCARE      <const> = {}
local INDEX        <const> = {1,2,3}
local pairs        <const> = pairs
local setmetatable <const> = setmetatable
local table_unpack <const> = table.unpack
local HEAD         <const> = 1
local TAIL         <const> = 2
local HEAD_INIT    <const> = TAIL + 1
local TAIL_INIT    <const> = HEAD_INIT - 1

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
                local tail = mb[TAIL] + 1
                mb[TAIL] = tail
                mb[tail] = message
				local c = message.__count
				if c then
					message.__count = c + 1
				end
            end
        end
    end
end

local mailbox = {}
mailbox.__index = mailbox

local function next_each(mb)
    local h = mb[HEAD]
    local msg = mb[h]
    if msg then
		local c = msg.__count
		if c then
			if c == 1 then
				msg.close(msg)
			else
				msg.__count = c - 1
			end
		end
        mb[h] = nil
        mb[HEAD] = h + 1
        return msg
    end
    mb[HEAD] = HEAD_INIT
    mb[TAIL] = TAIL_INIT
end

function mailbox:each()
    return next_each, self
end

local function next_unpack(mb)
    local h = mb[HEAD]
    local msg = mb[h]
    if msg then
		local c = msg.__count
		if c then
			if c == 1 then
				msg.close(msg)
			else
				msg.__count = c - 1
			end
		end
        mb[h] = nil
        mb[HEAD] = h + 1
        return table_unpack(msg)
    end
    mb[HEAD] = HEAD_INIT
    mb[TAIL] = TAIL_INIT
end

function mailbox:unpack()
    return next_unpack, self
end

function mailbox:clear()
	local i = self[HEAD]
	while true do
		local m = self[i]
		if m then
			local c = m.__count
			if c then
				m.__count = c - 1
				if c == 1 then
					m.close(m)
				end
			end
			self[i] = nil
		else
			break
		end
		i = i + 1
	end
    self[HEAD] = HEAD_INIT
    self[TAIL] = TAIL_INIT
end

mailbox.__gc = mailbox.clear

local world = {}

function world:sub(pattern)
    local mb = setmetatable({HEAD_INIT,TAIL_INIT}, mailbox)
    local lookup = self._event_lookup
    self._event_pattern[mb] = copytable(pattern)
    for i = 1, #INDEX do
        local k = INDEX[i]
        local v = pattern[k] or NOTCARE
        pattern[k] = nil
        local l = lookup[v]
        if not l then
            l = {}
            lookup[v] = l
        end
        lookup = l
    end
    lookup[mb] = compile_pattern(pattern)
    return mb
end

function world:unsub(mb)
    local lookup = self._event_lookup
    local pattern = self._event_pattern[mb]
    for i = 1, #INDEX do
        local k = INDEX[i]
        local v = pattern[k] or NOTCARE
        lookup = lookup[v]
    end
    self._event_pattern[mb] = nil
    lookup[mb] = nil
end

local function pubmessage(lookup, message, n)
    if lookup[NOTCARE] then
        pubmessage(lookup[NOTCARE], message, n+1)
    end
    local k = INDEX[n]
    if k == nil then
        return msg_push(message, lookup)
    end
    local v = message[k]
    if not v or not lookup[v] then
        return
    end
    return pubmessage(lookup[v], message, n+1)
end

function world:pub(message)
    local lookup = self._event_lookup
	if message.close then
		message.__count = 0
	    pubmessage(lookup, message, 1)
		if message.__count == 0 then
			message.close(message)
		end
	else
	    pubmessage(lookup, message, 1)
	end
end

local m = {}

function m:init()
    self._event_lookup = {}
    self._event_pattern = {}
    self.sub = world.sub
    self.pub = world.pub
    self.unsub = world.unsub
end

return m
