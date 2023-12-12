local fs = require "filesystem"
local datalist = require "datalist"
local aio = import_package "ant.io"

local function split(s)
    local r = {}
    s:match "^/?(.-)/?$":gsub('[^/]*', function (w) r[#r+1] = w end)
    return r
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

local function create(paths)
    local lst = {}
    for _, path in ipairs(paths) do
        if fs.exists(fs.path(path)) then
            lst[#lst+1] = assert(datalist.parse(aio.readall(path)))
        end
    end
    local obj = {}
    function obj:get(key)
        local sp = split(key)
        for _, l in ipairs(lst) do
            local t = get_internal(l, sp, 1)
            if t then
                local k = sp[#sp]
                return t[k]
            end
        end
    end
    return obj
end

return create {
    "/graphic_settings.ant",
    "/pkg/ant.settings/default/graphic_settings.ant",
    "/general_settings.ant",
    "/pkg/ant.settings/default/general_settings.ant",
}
