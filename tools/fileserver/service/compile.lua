package.path = "engine/?.lua"
require "bootstrap"

local ltask = require "ltask"
local arg = ltask.call(ltask.queryservice "arguments", "QUERY")
local REPOPATH = arg[1]

require "editor.create_repo" (REPOPATH)
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
