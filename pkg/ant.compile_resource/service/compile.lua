local repopath = ...

local ltask = require "ltask"

if repopath then
    local access = dofile "/engine/editor/vfs_access.lua"
    dofile "/engine/editor/create_repo.lua" (repopath, access)
end

local cr = require "main"

local S = {}

local CacheCompileId = {}
local CacheConfig = {}

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

function S.SETTING(setting)
    local key = stringify(setting)
    local CompileId = CacheCompileId[key]
    if CompileId == true then
        ltask.wait(key)
        return CacheCompileId[key]
    elseif CompileId ~= nil then
        return CompileId
    end
    CacheCompileId[key] = true
    local config = cr.init_config(setting)
    CompileId = #CacheConfig + 1
    CacheConfig[CompileId] = config
    CacheCompileId[key] = CompileId
    return CompileId
end

function S.COMPILE(id, path)
    return cr.compile_file(CacheConfig[id], path)
end

function S.VERIFY(id, paths)
    local lpaths = {}
    for i = 1, #paths do
        lpaths[i] = cr.verify_file(CacheConfig[id], paths[i])
    end
    return lpaths
end

function S.QUIT()
    ltask.quit()
end

return S
