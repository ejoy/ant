local json = require "packages.debugger.common.json"
local patch = require "packages.serialize.patch"

local function readfile(file)
    local f = assert(io.open(file, "r"))
    local data = f:read "a"
    f:close()
    return data
end

local MapMetatable <const> = {__name = 'serialize.map'}

local function update_metatable(t)
    if getmetatable(t) then
        assert(next(t) == nil)
        setmetatable(t, MapMetatable)
        return
    end
    for _, v in pairs(t) do
        if type(v) == "table" then
            update_metatable(v)
        end
    end
end

local function json_decode(file)
    local res = json.decode(readfile(file))
    update_metatable(res)
    return res
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

local function run_test(data)
    local ok, res = patch.apply(data.doc, data.patch)
    if data.error then
        return ok == false
    end
    if ok ~= true then
        return false
    end
    if data.expected then
        return equal(res, data.expected)
    end
    return true
end

for _, data in ipairs(json_decode "packages/serialize/test/patch.json") do
    if not run_test(data) then
        print("FAILED:", data.comment)
        run_test(data)
    end
end
