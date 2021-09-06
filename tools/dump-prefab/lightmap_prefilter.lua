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

local DEFAULT_LIGHTMAP_SIZE<const> = 128

local function prefilter(respath)
    local prefab = serialize.parse(respath, serialize.read_file(respath))

    local lm_prefab = {}
    for idx, e in ipairs(prefab) do
        if e.prefab then
            local pp = fs.path(e.prefab)
            if not pp:is_absolute() then
                pp = respath:parent_path() / pp
            end

            lm_prefab[idx] = prefilter(pp)
        else
            local function is_render_obj(e)
                for _, p in ipairs(e.policy) do
                    if p:match "ant.render|render" then
                        return e.data.mesh ~= nil and e.data.material ~= nil
                    end
                end
            end

            local function is_animation_obj(e)
                for _, p in ipairs(e.policy) do
                    return p:match "ant.animation|animation" ~= nil
                end
            end

            local function is_lm_obj(e)
                return is_render_obj(e) and not is_animation_obj(e) and e.data.widget_entity == nil
            end

            if is_lm_obj(e) then
                local lm = e.data.lightmap
                if lm == nil then
                    lm = {id = crypt.uuid(), size=DEFAULT_LIGHTMAP_SIZE}
                    e.data.lightmap = lm
                else
                    assert(lm.size ~= nil)
                    if lm.id == nil then
                        lm.id = crypt.uuid()
                    end
                end

                lm_prefab[idx] = {
                    lightmap = lm
                }
            else
                lm_prefab[idx] = {}
            end
        end

        return lm_prefab
    end

end

local function prefilter_(respath, lmr_path)
    local lmr_e = prefilter(respath)
    if lmr_path == nil then
        local dir = respath:parent_path():localpath()
        lmr_path = dir / "output/lightmaps/lightmap_result.prefab"
        lfs.create_directories(lmr_path:parent_path())
    end
    write_file(lmr_path, lmr_e)
end

return {
    build = build,
    prefilter = prefilter,
}