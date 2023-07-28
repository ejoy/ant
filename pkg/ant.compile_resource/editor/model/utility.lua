local serialize     = import_package "ant.serialize"
local fs            = require "bee.filesystem"
local serialization = require "bee.serialization"
local patch         = require "editor.model.patch"
local currentRoot

local function normalizePath(path)
    assert(path:sub(1,2) == "./")
    return path:sub(3)
end

local function writeFile(path, data)
    path = currentRoot / path
    fs.create_directories(path:parent_path())
    local f <close> = assert(io.open(path:string(), "wb"))
    f:write(data)
end

local m = {}

function m.init(output)
    currentRoot = output
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
    data = patch.apply(path, data)
    writeFile(path, serialize.stringify(data, conv))
end

function m.apply_patch(path, data)
    return patch.apply(normalizePath(path), data)
end

function m.full_path(path)
    return currentRoot / normalizePath(path)
end

function m.rename(src, dst)
    -- try 10 times
    for _= 1, 10 do
        if pcall(fs.rename, src, dst) then
            return
        end
    end

    error(("rename:%s, to:%s"):format(src:string(), dst:string()))
end

return m
