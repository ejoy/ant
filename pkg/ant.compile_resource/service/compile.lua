local repopath = ...

local vfs = require "vfs"

if repopath then
    local access = dofile "/engine/editor/vfs_access.lua"
    dofile "/engine/editor/create_repo.lua" (repopath, access)
end

local cr = require "main"

local S = {}

function S.COMPILE(path)
    return cr.compile_file(vfs.realpath(path))
end

function S.SETTING(setting)
    cr.set_setting(setting)
end

return S
