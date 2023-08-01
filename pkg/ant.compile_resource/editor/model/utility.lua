local serialize     = import_package "ant.serialize"
local fs            = require "bee.filesystem"
local serialization = require "bee.serialization"
local patch         = require "editor.model.patch"

local function normalizePath(path)
    assert(path:sub(1,2) == "./")
    return path:sub(3)
end

local function writeFile(status, path, data)
    path = status.output / path
    fs.create_directories(path:parent_path())
    local f <close> = assert(io.open(path:string(), "wb"))
    f:write(data)
end

local m = {}

function m.save_file(status, path, data)
    path = normalizePath(path)
    writeFile(status, path, data)
end

function m.save_bin_file(status, path, data)
    path = normalizePath(path)
    writeFile(status, path, serialization.packstring(data))
end

function m.save_txt_file(status, path, data, conv)
    path = normalizePath(path)
    data = patch.apply(status.patch, path, data)
    writeFile(status, path, serialize.stringify(data, conv))
end

function m.apply_patch(status, path, data)
    return patch.apply(status.patch, normalizePath(path), data)
end

function m.full_path(status, path)
    return status.output / normalizePath(path)
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
