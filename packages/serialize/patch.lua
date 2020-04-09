local m = {}

local MapMetatable <const> = {__name = 'serialize.map'}
local function markMap(t)
    if next(t) == nil then
        return setmetatable(t, MapMetatable)
    end
    return t
end

local function isArray(t)
    local first_value = next(t)
    if first_value == nil then
        local mt = getmetatable(t)
        if mt and mt.__name == 'serialize.map' then
            return false
        end
        return true
    end
    if type(first_value) == "number" then
        return true
    end
    return false
end

local function split(s)
    local r = {}
    s:gsub('[^/]*', function (w)
        r[#r+1] = w:gsub("~1", "/"):gsub("~0", "~")
    end)
    return r
end

local function query_(data, pathlst, n)
    if type(data) ~= "table" then
        return
    end
    local k = pathlst[n]
    local isarray = isArray(data)
    if isarray then
        if k == "-" then
            k = #data + 1
        else
            k = tonumber(k)
            if k == nil or math.type(k) ~= "integer" or k <= 0 or k > #data + 1 then
                return
            end
        end
    end
    if n == #pathlst then
        return data, k, isarray
    end
    return query_(data[k], pathlst, n + 1)
end

local function query(data, path)
    if type(path) ~= "string" then
        return
    end
    if path:sub(1,1) ~= "/" then
        return false
    end
    return query_(data, split(path:sub(2)), 1)
end

local function get(data, path)
    if path == '' then
        return true, data
    end
    local t, k = query(data, path)
    if not t then
        return false
    end
    if t[k] == nil then
        return false
    end
    return true, t[k]
end

local function add(data, path, value)
    if value == nil then
        return false
    end
    if path == '' then
        return true, value
    end
    local t, k, isarray = query(data, path)
    if not t then
        return false
    end
    if isarray then
        table.insert(t, k, value)
    else
        t[k] = value
    end
    return true, data
end

local function remove(data, path)
    if path == '' then
        return true, nil
    end
    local t, k, isarray = query(data, path)
    if not t then
        return false
    end
    if isarray then
        if k > #t then
            return false
        end
        table.remove(t, k)
    else
        if t[k] == nil then
            return false
        end
        t[k] = nil
        markMap(t)
    end
    return true, data
end

local function replace(data, path, value)
    if value == nil then
        return false
    end
    if path == '' then
        return true, value
    end
    local t, k = query(data, path)
    if not t then
        return false
    end
    t[k] = value
    return true, data
end

local function spin(data, path)
    if path == '' then
        return false
    end
    local t, k, isarray = query(data, path)
    if not t then
        return false
    end
    if t[k] == nil then
        return false
    end
    local oldvalue = t[k]
    t[k] = nil
    if not isarray then
        markMap(t)
    end
    return true, oldvalue
end

local function equal_(a, b)
    if type(a) == "table" then
        if type(b) ~= "table" then
            return false
        end
        for k, v in pairs(a) do
            if not equal_(v, b[k]) then
                return false
            end
        end
        return true
    end
    return a == b
end

local function equal(a, b)
    return equal_(a, b) and equal_(b, a)
end

function m.get(data, path)
    return get(data, path)
end

function m.set(data, path, value)
    return add(data, path, value)
end

local op = {}

function op:add(data)
    return add(data, self.path, self.value)
end

function op:remove(data)
    return remove(data, self.path)
end

function op:replace(data)
    return replace(data, self.path, self.value)
end

function op:copy(data)
    local ok, res = get(data, self.from)
    if not ok then
        return false
    end
    return replace(data, self.path, res)
end

function op:move(data)
    if self.from == self.path then
        return true, data
    end
    local ok, res = spin(data, self.from)
    if not ok then
        return false
    end
    return replace(data, self.path, res)
end

function op:test(data)
    local ok, res = get(data, self.path)
    return (ok and equal(res, self.value)), data
end

function m.apply(data, patchs, n)
    local ok
    for i = n or 1, #patchs do
        local patch = patchs[i]
        local method = op[patch.op]
        if not method then
            return false
        end
        ok, data = method(patch, data)
        if not ok then
            return false
        end
    end
    return true, data
end

return m
