local rdebug = require 'remotedebug'


local framePool = {}


local table_mt = {}
local func_mt = {}
local ud_mt = {}

local function wrap_v(v)
	local t = rdebug.type(v)
	if t == 'table' then
		return setmetatable({ __ref = v }, table_mt)
    elseif t == 'function' then
		return setmetatable({ __ref = v }, func_mt)
    elseif t == 'userdata' then
		return setmetatable({ __ref = v }, ud_mt)
    end
	return rdebug.value(v)
end

function table_mt:__index(k)
	local key = k
	if type(k) == 'table' then
		k = k.__ref
	end
	local v = rdebug.index(self.__ref, k)
	if v then
		v = wrap_v(v)
		self[key] = v
		return v
	end
end

local function frameCreate(frameId)
    local frame = {}

    local i = 1
    local f = rdebug.getfunc(frameId)
	while true do
		local name, value = rdebug.getupvalue(f, i)
		if name == nil then
			break
        end
        frame[name] = wrap_v(value)
        i = i + 1
    end

    local i = 1
	while true do
		local name, value = rdebug.getlocal(frameId, i)
		if name == nil then
			break
        end
        if name:sub(1,1) ~= '(' then
            frame[name] = wrap_v(value)
        end
        i = i + 1
    end
    return frame
end

local function frameGet(frameId)
    if not framePool[frameId] then
        framePool[frameId] = frameCreate(frameId)
    end
    return framePool[frameId]
end

local frame

local function get(name)
    if frame[name] then
        return frame[name]
    end
    local value = rdebug.index(rdebug._G, name)
    if value then
        return wrap_v(value)
    end
end

local m = {}


function m.complie(str)
    local mt = {}
    function mt:__index(key)
        return get(key)
    end
    return load(str, str, 't', setmetatable({}, mt))
end

function m.execute(frameId, f)
    frame = frameGet(frameId)
    return pcall(f)
end

return m
