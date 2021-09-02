local serialize = import_package "ant.serialize"
local crypt = require "crypt"
local datalist = require "datalist"
local fs = require "filesystem"
local lfs = require "filesystem.local"

local function read_file(path) local f<close> = fs.open(path); return f:read "a" end
local function write_file(path, c) local f<close> = lfs.open(path, "w"); f:write(c) end

local function find_all_prefab(path, prefabs)
    assert(path:is_absolute())
    local c = read_file(path)
    local p = datalist.parse(c)
    prefabs[#prefabs+1] = {
        path = path,
        value = p,
    }
    for _, v in ipairs(p) do
        if v.prefab then
            local pp = fs.path(v.prefab)
            if not pp:is_absolute() then
                pp = path:parent_path() / pp
            end
            find_all_prefab(pp, prefabs)
        end
    end
end

return {
    build = function (respath)
        local prefabs = {}
        find_all_prefab(respath, prefabs)
        for _, p in ipairs(prefabs) do
            local change
            for _, e in ipairs(p.value) do
                if e.data then
                    local lm = e.data.lightmap
                    if lm and lm.id == nil then
                        lm.id = crypt.uuid()
                        change = true
                    end
                end
            end

            if change then
                write_file(p.path:localpath(), serialize.stringify(p.value))
            end
        end
    end
}