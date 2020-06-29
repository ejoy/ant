local json = require "packages.json.json"
local patch = require "packages.serialize.patch"
patch.set_object_metatable(json.object)

local function readfile(file)
    local f = assert(io.open(file, "r"))
    local data = f:read "a"
    f:close()
    return data
end

local function json_decode(file)
    return json.decode(readfile(file))
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
    if data.disabled then
        return true
    end
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
        print("FAILED:", data.error and data.error or data.comment)
        run_test(data)
    end
end

print "OK"
