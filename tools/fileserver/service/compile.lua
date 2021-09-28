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
    local dir = {}
    pathstring:gsub('[^/]+', function (w)
        dir[#dir+1] = w
        if w:match "%?" then
            lst[#lst+1] = table.concat(dir, "/")
            dir = {}
        end
    end)
    if #dir > 0 then
        lst[#lst+1] = table.concat(dir, "/")
    end
    return vfs.resource(lst)
end

function S.COMPILE(path)
    return compile_url(path):string()
end

function S.QUIT()
    ltask.quit()
end

return S
