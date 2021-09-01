local assetmgr = import_package "ant.asset"
local math3d = require "math3d"
local maxid = 0

local create_prefab; do
    local function create_template(_, t)
        local prefab = {}
        for _, v in ipairs(t) do
            local e = {}
            if v.prefab then
                e.prefab = create_prefab(v.prefab)
                if v.args and v.args.root then
                    e.root = v.args.root
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
                if v.data.light_type then
                    e.light = {
                        type = v.data.light_type,
                        intensity = v.data.intensity,
                        color = v.data.color,
                        range = v.data.range,
                        radian = v.data.radian,
                    }
                end
                if v.data.material then
                    e.material = assetmgr.resource(v.data.material)
                end
                if v.data.lightmap then
                    e.lightmap = v.data.lightmap
                end
            end
            prefab[#prefab+1] = e
        end
        return prefab
    end
    local callback = { create_template = create_template }
    function create_prefab(filename)
        return assetmgr.resource(filename, callback)
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
    instance_(w, create_prefab(filename))
end

return {
    instance = instance
}
