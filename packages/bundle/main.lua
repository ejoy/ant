local ltask = require "ltask"
local ServiceBundle = ltask.uniqueservice "ant.bundle|bundle"
local bundle = require "bundle"

local m = {}

local Bundle = {}
local view = bundle.create_view {}

function m.open(path)
    if Bundle[path] then
        return
    end
    Bundle[path] = ltask.call(ServiceBundle, "open_bundle", path)
    local data = {}
    for _, v in pairs(Bundle) do
        data[#data+1] = v
    end
    view = bundle.create_view(data)
end

function m.get(path)
    local v = view[path]
    if v then
        return v
    end
    return ltask.call(ServiceBundle, "open_file", path)
end

return m
