local ltask = require "ltask"
local ServiceBundle = ltask.uniqueservice "ant.bundle|bundle"
local bundle = require "bundle"

local m = {}

local Bundle = {}
local view = bundle.create_view {}

local function rebuild()
    local data = {}
    for _, v in pairs(Bundle) do
        data[#data+1] = v
    end
    view = bundle.create_view(data)
end

function m.open(path)
    if Bundle[path] then
        return
    end
    Bundle[path] = ltask.call(ServiceBundle, "open_bundle", path)
    rebuild()
end

function m.close(path)
    if not Bundle[path] then
        return
    end
    ltask.call(ServiceBundle, "close_bundle", path)
    Bundle[path] = nil
    rebuild()
end

function m.get(path)
    local v = view[path]
    if v then
        return v
    end
    return ltask.call(ServiceBundle, "open_file", path)
end

return m
