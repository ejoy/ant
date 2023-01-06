local ecs = ...
local world = ecs.world
local w = world.w

local MAX_LAYER<const> = 16

local layer_names = {
    "FOREGROUNG", "DEFAULT", "BACKGROUND", "TRANSLUCENT",
}

local function find_layeridx(name)
    for idx, ln in ipairs(layer_names) do
        if ln == name then
            return idx
        end
    end
end

local irl = ecs.interface "irender_layer"

function irl.add_layer(name, after_layeridx)
    if #layer_names >= MAX_LAYER then
        error(("Too many render layer, max is :%d"):format(MAX_LAYER))
    end


end

function irl.layer_name(layeridx)
    return layer_names[layeridx]
end

function irl.defualt_layer()
    return assert(find_layeridx "DEFAULT")
end