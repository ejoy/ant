local lua_patch = require "util.lua_patch"
local lfs       = require "bee.filesystem"
local depends   = require "depends"
local fastio    = require "fastio"
local serialize = import_package "ant.serialize"

local m = {}

local function absolute_path(path, base)
    if path:sub(1,1) == "/" then
        return path
    end
    return base:match "^(.-)[^/]*$" .. (path:match "^%./(.+)$" or path)
end

local function load_patch(patchLst, depfiles, lpath, vpath)
    depends.add_lpath(depfiles, lpath)
    for _, patch in ipairs(serialize.parse(fastio.readall_f(lpath), vpath)) do
        if patch.include then
            load_patch(patchLst, depfiles, absolute_path(patch.include, lpath), absolute_path(patch.include, vpath))
        else
            local file = assert(patch.file)
            patch.file = nil
            if patchLst[file] then
                table.insert(patchLst[file], patch)
            else
                patchLst[file] = {patch}
            end
        end
    end
end

function m.init(lpath, vpath, depfiles)
    lpath = lpath..".patch"
    vpath = vpath..".patch"
    if not lfs.exists(lpath) then
        depends.add_lpath(depfiles, lpath)
        return {}
    end
    local patchLst = {}
    load_patch(patchLst, depfiles, lpath, vpath)
    return patchLst
end

function m.apply(status, path, data, retval)
    local patch = status.patch[path]
    if not patch then
        return data
    end
    local ok, res = lua_patch.apply(data, patch, retval)
    assert(ok == true, res)
    return res
end

return m
