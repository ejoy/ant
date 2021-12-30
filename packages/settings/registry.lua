local fs = require 'filesystem'
local datalist = require 'datalist'

local mt = {}
mt.__index = mt

local function load(path)
    local f = assert(fs.open(path, 'r'))
    local str = f:read 'a'
    f:close()
    return str
end

local function split(s)
    local r = {}
    s:match "^/?(.-)/?$":gsub('[^/]*', function (w) r[#r+1] = w end)
    return r
end

local function query_internal(t, sp, n)
    if n > #sp then
        return t
    end
    local node = t[sp[n]]
    if type(node) ~= 'table' then
        return
    end
    return query_internal(node, sp, n+1)
end

local function query(t, path)
    local sp = split(path)
    return query_internal(t, sp, 1)
end

local function get_internal(t, sp, n)
    if n >= #sp then
        return t
    end
    local node = t[sp[n]]
    if type(node) ~= 'table' then
        return
    end
    return get_internal(node, sp, n+1)
end

local function set_internal(t, sp, n)
    if n >= #sp then
        return t
    end
    local node = t[sp[n]]
    if type(node) ~= 'table' then
        node = {}
        t[sp[n]] = node
    end
    return set_internal(node, sp, n+1)
end

function mt:get(path)
    local sp = split(path)
    for _, l in ipairs(self._l) do
        local t = get_internal(l, sp, 1)
        if t then
            local k = sp[#sp]
            local r = t[k]
            if type(r) == 'table' then
                return
            end
            return r
        end
    end
end

function mt:set(path, value)
    local sp = split(path)
    local t = set_internal(self._data, sp, 1)
    if not t then
        return false
    end
    local k = sp[#sp]
    t[k] = value
    return true
end

function mt:enum_key(path)
    local sort = {}
    local mark = {}
    for _, l in ipairs(self._l) do
        local t, k = query(l, path)
        if t then
            for k, v in pairs(t[k]) do
                if not mark[k] and type(v) == 'table' then
                    sort[#sort+1] = k
                    mark[k] = true
                end
            end
        end
    end
    table.sort(sort)
    local n = 1
    return function ()
        local k = sort[n]
        if not k then return end
        n = n + 1
        return k
    end
end

function mt:enum_value(path)
    local sort = {}
    local mark = {}
    for _, l in ipairs(self._l) do
        local t, k = query(l, path)
        if t then
            for k, v in pairs(t[k]) do
                if not mark[k] and type(v) ~= 'table' then
                    sort[#sort+1] = {k, v}
                    mark[k] = true
                end
            end
        end
    end
    table.sort(sort, function(a, b) return a[1] < b[1] end)
    local n = 1
    return function ()
        local kv = sort[n]
        if not kv then return end
        n = n + 1
        return kv[1], kv[2]
    end
end

local function is_array(t)
    for k in pairs(t) do
        if not (type(k) == "number" and math.type(k) == "integer") then
            return
        end
    end

    return true
end

function mt:data()
    local l = self._l
    local function proxy(prefix)
        local mt = {}
        function mt:__index(k)
            local path = prefix .. '/' .. k
            local sp = split(path)
            for _, l in ipairs(l) do
                local t = get_internal(l, sp, 1)
                if t then
                    local v = t[sp[#sp]]
                    if type(v) == 'table' and (not is_array(v)) then
                        return proxy(path)
                    end
                    if v ~= nil then
                        return t[k]
                    end
                end
            end
        end
        function mt:__newindex()
            error "Modify registry needs to use the `set` method."
        end

        function mt:__len()
            local sp = split(prefix)
            for _, ll in ipairs(l) do
                local v = get_internal(ll, sp, 1)
                if type(v) == 'table' then
                    return #v[sp[#sp]]
                end
            end
        end

        function mt:__ipairs()
            local path = prefix
            local sp = split(path)
            local data
            for _, ll in ipairs(l) do
                local v = get_internal(ll, sp, 1)
                if type(v) == 'table' then
                    data = v[sp[#sp]]
                    break
                end
            end
            return function (t, i)
                return t[i]
            end, data, 0
        end
        function mt:__pairs()
            local path = prefix
            local sort = {}
            local mark = {}
            for _, l in ipairs(l) do
                local t, k = query(l, path)
                if t then
                    for k, v in pairs(t[k]) do
                        if not mark[k] then
                            sort[#sort+1] = {k, v}
                            mark[k] = true
                        end
                    end
                end
            end
            table.sort(sort, function(a, b) return a[1] < b[1] end)
            local n = 1
            return function ()
                local kv = sort[n]
                if not kv then return end
                n = n + 1
                local k, v = kv[1], kv[2]
                if type(v) == 'table' and is_array(v) then
                    return k, proxy(path .. '/' .. k)
                end
                return k, v
            end
        end
        return setmetatable({}, mt)
    end
    return proxy('')
end

function mt:use(path)
    local t = query(self._data, '_'..path)
    if not t then
        return false
    end
    local l = self._l
    for i = #l, 1, -1 do
        if l[i] == t then
            return false
        end
        l[i+1] = l[i]
    end
    l[1] = t
    return true
end

local m = {}

function m.create(path, mode)
    local self = setmetatable({}, mt)
    if mode ~= 'r' then
        self._path = path
    end
    local data = datalist.parse(load(path))
    if not data then
        return
    end
    self._data = data
    self._l = {data}
    return self
end

return m
