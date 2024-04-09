local m = {}

local ObjectMetatable = {}
local function markObject(t)
    if next(t) == nil then
        return setmetatable(t, ObjectMetatable)
    end
    return t
end

local TableEmpty <const> = 0
local TableArray <const> = 1
local TableObject <const> = 2

local function TableType(t)
    local first_value = next(t)
    if first_value == nil then
        if getmetatable(t) == ObjectMetatable then
            return TableObject
        end
        return TableEmpty
    end
    if type(first_value) == "number" then
        return TableArray
    end
    return TableObject
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
    local tableType = TableType(data)
    if tableType == TableArray then
        if k == "-" then
            k = #data + 1
        else
            if k:match "^0%d+" then
                return
            end
            k = tonumber(k)
            if k == nil or math.type(k) ~= "integer" or k <= 0 or k > #data + 1 then
                return
            end
        end
    end
    if n == #pathlst then
        return data, k, tableType
    end
    return query_(data[k], pathlst, n + 1)
end

local function query(data, path)
    if type(path) ~= "string" then
        return
    end
    if path:sub(1,1) ~= "/" then
        return
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
    local t, k, t_type = query(data, path)
    if not t then
        return false
    end
    if t_type == TableArray then
        if type(k) ~= "number" then
            return false
        end
        table.insert(t, k, value)
    elseif t_type == TableObject then
        if type(k) ~= "string" then
            return false
        end
        t[k] = value
    elseif t_type == TableEmpty then
        if type(k) == "number" then
            if k ~= 1 then
                return false
            end
            t[1] = value
        elseif type(k) == "string" then
            t[k] = value
        else
            return false
        end
    end
    return true, data
end

local function remove(data, path)
    if path == '' then
        return true, nil
    end
    local t, k, t_type = query(data, path)
    if not t then
        return false
    end
    if t_type == TableArray then
        if type(k) ~= "number" then
            return false
        end
        if k > #t then
            return false
        end
        table.remove(t, k)
    elseif t_type == TableObject then
        if type(k) ~= "string" then
            return false
        end
        if t[k] == nil then
            return false
        end
        t[k] = nil
        markObject(t)
    elseif t_type == TableEmpty then
        -- nothing to do
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
    local t, k, t_type = query(data, path)
    if not t then
        return false
    end
    if t_type == TableArray then
        if type(k) ~= "number" then
            return false
        end
    elseif t_type == TableObject then
        if type(k) ~= "string" then
            return false
        end
    elseif t_type == TableEmpty then
        if type(k) == "number" then
            if k ~= 1 then
                return false
            end
        elseif type(k) == "string" then
        else
            return false
        end
    end
    t[k] = value
    return true, data
end

local function spin(data, path)
    if path == '' then
        return false
    end
    local t, k, t_type = query(data, path)
    if not t then
        return false
    end
    if t[k] == nil then
        return false
    end
    if t_type == TableArray then
        if type(k) ~= "number" then
            return false
        end
        local oldvalue = table.remove(t, k)
        return true, oldvalue
    elseif t_type == TableObject then
        if type(k) ~= "string" then
            return false
        end
        local oldvalue = t[k]
        t[k] = nil
        markObject(t)
        return true, oldvalue
    elseif t_type == TableEmpty then
        return true
    end
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

local function deepcopy(t)
    if type(t) ~= "table" then
        return t
    end
    local r = {}
    for k, v in pairs(t) do
        r[k] = deepcopy(v)
    end
    if TableType(t) == TableObject then
        markObject(r)
    end
    return r
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
    return replace(data, self.path, deepcopy(res))
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
    if ok and equal(res, self.value) then
        return true, data
    end
    return false
end

function op:copyfile(data, retval)
    retval[self.path] = deepcopy(data)
    return true, data
end

function op:createfile(data, retval)
    retval[self.path] = self.value
    return true, data
end

function m.apply(data, patchs, retval)
    local ok
    for i = 1, #patchs do
        local patch = patchs[i]
        local method = op[patch.op]
        if not method then
            return false
        end
        ok, data = method(patch, data, retval)
        if not ok then
            return false
        end
    end
    return true, data
end

function m.set_object_metatable(mt)
    ObjectMetatable = mt
end

return m
