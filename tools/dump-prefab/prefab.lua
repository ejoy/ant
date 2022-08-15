local assetmgr = import_package "ant.asset"
local math3d = require "math3d"
local maxid = 0

local create_prefab; do
    local function create_template(info, t)
        local prefab = {}

        local prefab_lm = info.prefab_lightmap
        for idx, v in ipairs(t) do
            local e = {}
            local r = prefab_lm[idx]
            if v.prefab then
                --TODO: we should preprocess scene.prefab file
                if v.prefab:match "lightmap_result.prefab" == nil then
                    e.prefab = create_prefab(v.prefab, assert(r.prefab))
                    if v.args and v.args.root then
                        e.root = v.args.root
                    end
                end
            else
                maxid = maxid + 1
                e.id = maxid
                if v.action and v.action.mount then
                    e.parent = v.action.mount
                end
                if v.data.mesh then
                    e.mesh = assetmgr.resource(v.data.mesh)
                end
                if v.data.transform then
                    e.srt = math3d.matrix(v.data.transform)
                end
                local light = v.data.light
                if light then
                    e.make_shadow   = v.data.make_shadow
                    e.light         = light
                end
                if v.data.material then
                    e.material = assetmgr.resource(v.data.material)
                end

                local r_lm = r.lightmap
                if r_lm then
                    local data_lm = v.data.lightmap
                    if data_lm == nil then
                        data_lm = r_lm
                    else
                        data_lm.id = r_lm.id
                    end
                    e.lightmap = data_lm
                end

            end
            prefab[#prefab+1] = e
        end
        return prefab
    end

    function create_prefab(filename, prefab_lightmap)
        return assetmgr.resource(filename,  { prefab_lightmap = prefab_lightmap, create_template = create_template })
    end
end

local function instance_(w, prefab, root)
    for _, e in ipairs(prefab) do
        if e.prefab then
            if e.root then
                instance_(w, e.prefab, prefab[e.root])
            else
                instance_(w, e.prefab)
            end
        else
            if e.parent then
                if e.parent == "root" then
                    e.parent = root
                else
                    e.parent = prefab[e.parent]
                end
            end
            e.sorted = true
            w:new(e)
        end
    end
end

local function instance(w, filename)
    local lmr_e = w:first("lightmapper lightmap_result:in")
    instance_(w, create_prefab(filename, lmr_e.lightmap_result))
end

return {
    instance = instance
}
