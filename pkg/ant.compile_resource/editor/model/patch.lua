local serialize = import_package "ant.serialize"
local fs        = require "bee.filesystem"
local datalist  = require "datalist"
local fastio    = require "fastio"
local depends   = require "editor.depends"

local m = {}

local function absolute_path(path, base)
    if path:sub(1,1) == "/" then
        return path
    end
    return base:match "^(.-)[^/]*$" .. (path:match "^%./(.+)$" or path)
end

local function load_patch(patchLst, depfiles, path)
    depends.add(depfiles, path)
    for _, patch in ipairs(assert(datalist.parse(fastio.readall_s(path)))) do
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
    if not fs.exists(path) then
        depends.add(depfiles, path)
        return {}
    end
    local patchLst = {}
    load_patch(patchLst, depfiles, path)
    return patchLst
end

function m.apply(patchLst, path, data)
    local patch = patchLst[path]
    if not patch then
        return data
    end
    local ok, res = serialize.patch.apply(data, patch)
    assert(ok == true, res)
    return res
end

return m
