local serialize     = import_package "ant.serialize"
local crypt         = require "crypt"
local fs            = require "filesystem"
local lfs           = require "filesystem.local"

local function write_file(path, c) local f<close> = lfs.open(path, "w"); f:write(c) end

local function build_tree(respath, cache)
    local prefab = serialize.parse(respath, serialize.read_file(respath))
    local t = {}
    for idx, e in ipairs(prefab) do
        if e.prefab then
            local pp = fs.path(e.prefab)
            if not pp:is_absolute() then
                pp = respath:parent_path() / pp
            end

            t[idx] = {prefab = build_tree(pp)}
        else
            local tt = {}
            cache[crypt.uuid()] = tt
            t[idx] = tt
        end
    end

    return t
end

local function build(respath, lm_path)
    local lm_cache = {}
    local lmr_e = {
        policy = {
            "ant.render|lightmap_result",
            "ant.general|name"
        },
        data = {
            lightmap_result = build_tree(respath, lm_cache),
            lightmapper = true,
            name = "lightmap_result",
        }
    }
    
    local local_lmpath = lm_path:localpath()
    local lmr_file = local_lmpath / "lightmap_result.prefab"
    write_file(lmr_file, {lmr_e})

    local scene = serialize.parse(respath, serialize.read_file(respath))
    scene[#scene+1] = {
        lightmap_result_mount = {},
        prefab = local_lmpath / "lightmap_result.prefab",
    }

    return lmr_e, lm_cache
end

return {
    build = build,
}