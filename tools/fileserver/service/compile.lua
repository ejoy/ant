package.path = "engine/?.lua"
require "bootstrap"

local ltask = require "ltask"
local arg = ltask.call(ltask.queryservice "arguments", "QUERY")
local REPOPATH = arg[1]
local vfs = require "vfs"

require "editor.create_repo" (REPOPATH)
import_package "ant.compile_resource"

local S = {}

local function compile_url(pathstring)
    local lst = {}
    pathstring:gsub('[^#]+', function (w)
        lst[#lst+1] = w
    end)
    return vfs.resource(lst)
end

function S.COMPILE(path)
    return compile_url(path):string()
end

return S
