local project = ...
package.path = "engine/?.lua"
require "bootstrap"
require "editor.create_repo" (project)

import_package "ant.compile_resource"
local ltask = require "ltask"
local vfs = require "vfs"

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

function S.QUIT()
    ltask.quit()
end

return S
