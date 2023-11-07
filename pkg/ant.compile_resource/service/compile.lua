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

function S.SETTING(setting)
    local CompileId = CacheCompileId[setting]
    if CompileId == true then
        ltask.wait(setting)
        return CacheCompileId[setting]
    elseif CompileId ~= nil then
        return CompileId
    end
    CacheCompileId[setting] = true
    local config = cr.init_setting(require "vfs", setting)
    CompileId = #CacheConfig + 1
    CacheConfig[CompileId] = config
    CacheCompileId[setting] = CompileId
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
