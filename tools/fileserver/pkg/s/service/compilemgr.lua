local repopath = ...

local ltask = require "ltask"

local S = {}

local function sortpairs(t)
    local sort = {}
    for k in pairs(t) do
        sort[#sort+1] = k
    end
    table.sort(sort)
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

local function stringify(t)
    local s = {}
    for k, v in sortpairs(t) do
        s[#s+1] = k.."="..tostring(v)
    end
    return table.concat(s, "&")
end

local CACHE = {}

function S.spawn(setting)
    local key = stringify(setting)
    local id = CACHE[key]
    if id == true then
        ltask.wait(key)
        return CACHE[key]
    elseif id ~= nil then
        return id
    end
    CACHE[key] = true
    id = ltask.spawn("ant.compile_resource|compile", repopath)
    ltask.call(id, "SETTING", setting)
    CACHE[key] = id
    ltask.wakeup(key)
    return id
end

return S
