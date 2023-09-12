local repopath = ...

local vfs = require "vfs"

if repopath then
    local access = dofile "/engine/vfs/repoaccess.lua"
    dofile "/engine/editor/create_repo.lua" (repopath, access)
end

local cr = require "main"
cr.init_setting()

local S = {}

function S.COMPILE(path)
    return cr.compile_file(vfs.realpath(path))
end

function S.SETTING(ext, setting)
    cr.set_setting(ext, setting)
end

return S
