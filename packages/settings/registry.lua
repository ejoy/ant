local fs = require 'filesystem.local'

local mt = {}
mt.__index = mt

local function save(path, str)
    local f = assert(fs.open(path, 'w'))
    f:write(str)
    f:close()
    return true
end

local function load(path)
    local f = assert(fs.open(path, 'r'))
    local str = f:read 'a'
    f:close()
    return str
end

local function sort_kv(t, mode)
    local sort = {}
    for k, v in pairs(t) do
        if not mode or (mode == 'k') == (type(v) == 'table') then
            sort[#sort+1] = k
        end
    end
    table.sort(sort)
    return sort
end

local function enum_kv(t, mode)
    local sort = sort_kv(t, mode)
    local n = 1
    return function ()
        local k = sort[n]
        if k == nil then
            return
        end
        n = n + 1
        return k, t[k]
    end
end

local function convertreal(v)
    local g = ('%.16g'):format(v)
    if tonumber(g) == v then
        return g
    end
    return ('%.17g'):format(v)
end

local function stringify_value(v)
    if math.type(v) == 'float' then
        return convertreal(v)
    end
    return tostring(v)
end

local function stringify_table(s, t, n)
    local prefix = ('  '):rep(n)
    for k, v in enum_kv(t, 'v') do
        s[#s+1] = prefix..k..': '..stringify_value(v)
    end
    for k, v in enum_kv(t, 'k') do
        s[#s+1] = prefix..k..':'
        stringify_table(s, v, n+1)
    end
end

local function stringify(t)
    local s = {}
    stringify_table(s, t, 0)
    s[#s+1] = ''
    return table.concat(s, '\n')
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
            if type(t[k]) == 'table' then
                return
            end
            return t[k]
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
    if not self._path then
        return true
    end
    return save(self._path, stringify(self._data))
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
                    local k = sp[#sp]
                    local v = t[k]
                    if type(v) == 'table' then
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
                if type(v) == 'table' then
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
    local datalist = require 'datalist'
    local data = datalist.parse(load(path))
    if not data then
        return
    end
    self._data = data
    self._l = {data}
    return self
end

return m
