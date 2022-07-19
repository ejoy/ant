local ecs = ...

local ro = ecs.component "render_obj"
function ro.init()
    return {

    }
end

function ro.remove()
end

local function material_type(qn)
    
end

local function submit(r)

    r:submit(assetmgr.textures, mattype)
end