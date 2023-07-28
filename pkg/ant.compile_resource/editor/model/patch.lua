local serialize = import_package "ant.serialize"
local fs        = require "bee.filesystem"
local datalist  = require "datalist"
local fastio    = require "fastio"
local depends   = require "editor.depends"
local currentPatch

local m = {}

local function absolute_path(path, base)
    if path:sub(1,1) == "/" then
        return path
    end
    return base:match "^(.-)[^/]*$" .. (path:match "^%./(.+)$" or path)
end

local function load_patch(depfiles, path)
    depends.add(depfiles, path)
    for _, patch in ipairs(assert(datalist.parse(fastio.readall_s(path)))) do
        if patch.include then
            load_patch(depfiles, absolute_path(patch.include, path))
        else
            local file = assert(patch.file)
            patch.file = nil
            if currentPatch[file] then
                table.insert(currentPatch[file], patch)
            else
                currentPatch[file] = {patch}
            end
        end
    end
end

function m.init(input, depfiles)
    local path = input..".patch"
    currentPatch = {}
    if not fs.exists(path) then
        depends.add(depfiles, path)
        return
    end
    load_patch(depfiles, path)
end

function m.apply(path, data)
    local patch = currentPatch[path]
    if not patch then
        return data
    end
    local ok, res = serialize.patch.apply(data, patch)
    assert(ok == true, res)
    return res
end

return m
