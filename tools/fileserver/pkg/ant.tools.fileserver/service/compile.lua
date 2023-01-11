package.path = "/engine/?.lua"
require "bootstrap"
if package.loaded.math3d then
    error "need init math3d MAXPAGE"
end
debug.getregistry().MATH3D_MAXPAGE = 10240

local ltask = require "ltask"
local arg = ltask.call(ltask.queryservice "arguments", "QUERY")
local REPOPATH = arg[1]

local access = require "vfs.repoaccess"
require "editor.create_repo" (REPOPATH, access)
local fs = require "filesystem"
local cr = import_package "ant.compile_resource"

local S = {}

function S.COMPILE(path)
    return cr.compile_file(fs.path(path):localpath()):string()
end

function S.SETTING(ext, setting)
    cr.set_setting(ext, setting)
end

return S
