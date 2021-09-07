local serialize     = import_package "ant.serialize"
local cr            = import_package "ant.compile_resource"
local crypt         = require "crypt"
local fs            = require "filesystem"
local lfs           = require "filesystem.local"

local function write_file(path, c)
    local f<close> = lfs.open(path, "w")
    f:write(c)
end

local DEFAULT_LIGHTMAP_SIZE<const> = 128

local function prefilter(respath)
    local prefab = serialize.parse(respath:string(), cr.read_file(respath:string()))

    local lm_prefab = {}
    for idx, e in ipairs(prefab) do
        if e.prefab then
            if e.prefab:match "lightmap_result.prefab" == nil then
                local pp = fs.path(e.prefab)
                if not pp:is_absolute() then
                    pp = respath:parent_path() / pp
                end

                lm_prefab[idx] = {prefab = prefilter(pp)}
            end
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
    end
    return lm_prefab
end

local function save_lightmap_result(path, lme)
    local pp = path:parent_path()
    if not lfs.exists(pp) then
        lfs.create_directories(pp)
    end
    write_file(path, serialize.stringify({lme}))
end

return {
    prefilter = prefilter,
    save = save_lightmap_result,
}