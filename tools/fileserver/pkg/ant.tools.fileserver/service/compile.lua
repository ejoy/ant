package.path = "/engine/?.lua"
require "bootstrap"

local fs = require "bee.filesystem"
local ltask = require "ltask"
local arg = ltask.call(ltask.queryservice "arguments", "QUERY")
local REPOPATH = fs.absolute(arg[1]):lexically_normal():string()

local access = require "vfs.repoaccess"
require "editor.create_repo" (REPOPATH, access)
local vfs = require "vfs"
local cr = import_package "ant.compile_resource".fileserver()
cr.init_setting()

local S = {}

function S.COMPILE(path)
    return cr.compile_file(vfs.realpath(path))
end

function S.SETTING(ext, setting)
    cr.set_setting(ext, setting)
end

return S
