local serialize     = import_package "ant.serialize"
local lfs            = require "bee.filesystem"
local serialization = require "bee.serialization"
local patch         = require "model.patch"

local function writeFile(status, path, data, suffix)
    if suffix then
        local name, type = string.match(path, "([%a-_]+).([%a]+)")
        path = string.format("%s_%s.%s", name, suffix, type)
    end
    local lpath = status.output / path
    lfs.create_directories(lpath:parent_path())
    local f <close> = assert(io.open(lpath:string(), "wb"))
    f:write(data)
end

local m = {}

function m.save_file(status, path, data)
    writeFile(status, path, data)
end

function m.save_bin_file(status, path, data)
    writeFile(status, path, serialization.packstring(data))
end

function m.apply_patch(status, path, data, func)
    local retval = {}
    local patch_data = patch.apply(status, path, data, retval)
    func(path, patch_data)
    for name, v in pairs(retval) do
        m.apply_patch(status, name, v, func)
    end
end

function m.save_txt_file(status, path, data, conv, suffix)
    m.apply_patch(status, path, data, function (name, desc)
        writeFile(status, name, serialize.stringify(conv(desc)), suffix)
    end)
end

function m.full_path(status, path)
    return status.output / path
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
