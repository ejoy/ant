local rdebug = require 'remotedebug'
local variables = require 'new-debugger.worker.variables'

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

local G = {}

G._G = setmetatable({}, {__index = function(_, name)
    local v = rdebug.index(rdebug._G, name)
    if v then
        return wrap_v(v)
    end
end})

G.debug = {}

function G.debug.getmetatable(obj)
    if type(obj) == 'table' and obj.__ref then
        local v = rdebug.getmetatable(obj.__ref)
        if v then
            return wrap_v(v)
        end
    end
end

function G.debug.getuservalue(obj)
    if type(obj) == 'table' and obj.__ref then
        local v = rdebug.getuservalue(obj.__ref)
        if v then
            return wrap_v(v)
        end
    end
end

function G.debug.getlocal(frameId, i)
    local name, v = rdebug.getlocal(frameId, i)
    if name and v then
        return wrap_v(v)
    end
end

function G.debug.getupvalue(f, i)
    if type(f) == 'number' then
        f = rdebug.getfunc(f)
    elseif type(f) == 'table' and f.__ref then
        f = f.__ref
    else
        return
    end
    local name, v = rdebug.getupvalue(f, i)
    if name and v then
        return wrap_v(v)
    end
end

local frame

local function get(name)
    if frame[name] then
        return frame[name]
    end
    local value = G[name]
    if value then
        return value
    end
    local value = rdebug.index(rdebug._G, name)
    if value then
        return wrap_v(value)
    end
end

local m = {}


function m.complie(expression)
    local mt = {}
    function mt:__index(key)
        return get(key)
    end
    return load(expression, expression, 't', setmetatable({}, mt))
end

function m.execute(frameId, f, ...)
    frame = frameGet(frameId)
    return pcall(f, ...)
end

function m.clean()
    framePool = {}
end

function m.complie_then_execute(frameId, expression, ...)
    local f, err = m.complie(expression)
    if not f then
        return false, err
    end
    return m.execute(frameId, f, ...)
end

function m.run(frameId, expression, context)
    local res = table.pack(m.complie_then_execute(frameId, 'return ' .. expression))
    if not res[1] then
        if context ~= 'repl' then
            return false, res[2]
        end
        local ok, err = m.complie_then_execute(frameId, expression)
        if not ok then
            return false, err
        end
        return true, ''
    end
    table.remove(res, 1)
    local ref
    if type(res[1]) == 'table' then
        if res[1].__ref ~= nil then
            local _
            res[1], _, ref = variables.createRef(frameId, res[1].__ref, expression)
        else
            res[1] = 'nil'
        end
    end
    for i = 1, res.n - 1 do
        res[i] = tostring(res[i]) or 'nil'
    end
    if #res == 0 then
        return true, 'nil', ref
    end
    return true, table.concat(res, ','), ref
end

return m
