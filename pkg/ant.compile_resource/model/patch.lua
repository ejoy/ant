local serialize = import_package "ant.serialize"
local lfs       = require "bee.filesystem"
local datalist  = require "datalist"
local fastio    = require "fastio"
local depends   = require "depends"

local m = {}

local function absolute_path(path, base)
    if path:sub(1,1) == "/" then
        return path
    end
    return base:match "^(.-)[^/]*$" .. (path:match "^%./(.+)$" or path)
end

local function load_patch(patchLst, depfiles, path)
    depends.add_lpath(depfiles, path)
    for _, patch in ipairs(assert(datalist.parse(fastio.readall_f(path)))) do
        if patch.include then
            load_patch(patchLst, depfiles, absolute_path(patch.include, path))
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

function m.init(input, depfiles)
    local path = input..".patch"
    if not lfs.exists(path) then
        depends.add_lpath(depfiles, path)
        return {}
    end
    local patchLst = {}
    load_patch(patchLst, depfiles, path)
    return patchLst
end

function m.apply(status, path, data, retval)
    local patch = status.patch[path]
    if not patch then
        return data
    end
    local ok, res = serialize.patch.apply(data, patch, retval)
    assert(ok == true, res)
    return res
end

return m
