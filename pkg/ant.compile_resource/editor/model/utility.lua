local serialize = import_package "ant.serialize"
local lfs       = require "filesystem.local"
local datalist  = require "datalist"
local serialization = require "bee.serialization"
local currentRoot
local currentPatch

local function normalizePath(path)
    assert(path:sub(1,2) == "./")
    return path:sub(3)
end

local function readFile(path)
    local f = assert(lfs.open(path, 'rb'))
    local data = f:read 'a'
    f:close()
    return data
end

local function writeFile(path, data)
    path = currentRoot / path
    lfs.create_directories(path:parent_path())
    local f = assert(lfs.open(path, "wb"))
    f:write(data)
    f:close()
end

local function loadPatch(path)
    if not lfs.exists(path) then
        return {}
    end
    local res = {}
    for _, patch in ipairs(assert(datalist.parse(readFile(path)))) do
        local file = assert(patch.file)
        patch.file = nil
        if res[file] then
            table.insert(res[file], patch)
        else
            res[file] = {patch}
        end
    end
    return res
end

local function applyPatch(path, data)
    local patch = currentPatch[path]
    if not patch then
        return data
    end
    local ok, res = serialize.patch.apply(data, patch)
    assert(ok == true, res)
    return res
end

local m = {}

function m.init(input, output)
    currentRoot = output
    currentPatch = loadPatch(input..".patch")
end

function m.save_file(path, data)
    path = normalizePath(path)
    writeFile(path, data)
end

function m.save_bin_file(path, data)
    path = normalizePath(path)
    writeFile(path, serialization.packstring(data))
end

function m.save_txt_file(path, data, conv)
    path = normalizePath(path)
    data = applyPatch(path, data)
    writeFile(path, serialize.stringify(data, conv))
end

function m.apply_patch(path, data)
    return applyPatch(normalizePath(path), data)
end

function m.full_path(path)
    return currentRoot / normalizePath(path)
end

function m.rename(src, dst)
    -- try 10 times
    for _= 1, 10 do
        if pcall(lfs.rename, src, dst) then
            return
        end
    end

    error(("rename:%s, to:%s"):format(src:string(), dst:string()))
end

return m
