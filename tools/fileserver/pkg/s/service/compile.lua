
local vfs = require "vfs"
local cr

local S = {}

function S.INIT(repopath)
    local access = dofile "/engine/vfs/repoaccess.lua"
    dofile "/engine/editor/create_repo.lua" (repopath, access)
    cr = import_package "ant.compile_resource"
    cr.init_setting()
end

function S.COMPILE(path)
    return cr.compile_file(vfs.realpath(path))
end

function S.SETTING(ext, setting)
    cr.set_setting(ext, setting)
end

return S
