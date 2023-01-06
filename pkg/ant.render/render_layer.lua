local MAX_LAYER<const> = 16

local layer_names = {
    "foreground", "opacity", "background", "translucent", "decal", "ui"
}

local function find_layeridx(name)
    for idx, ln in ipairs(layer_names) do
        if ln == name then
            return idx
        end
    end
end

local irl = {}

function irl.add_layer(name, after_layeridx)
    local n = #layer_names
    if #layer_names >= MAX_LAYER then
        error(("Too many render layer, max is :%d"):format(MAX_LAYER))
    end

    after_layeridx = after_layeridx or n
    if after_layeridx == MAX_LAYER then
        error "Can not push another layer, it will larger than MAX_LAYER"
    end

    local next = #layer_names+1
    layer_names[next] = name
    return next
end

function irl.remove_layer(layeridx)
    if layeridx <= 0 or layeridx > MAX_LAYER then
        log.warn(("Invalid layeridx:%d"):format(layeridx))
        return
    end

    table.remove(layer_names, layeridx)
end

function irl.layeridx(name)
    return find_layeridx(name)
end

function irl.layername(layeridx)
    return layer_names[layeridx]
end

return irl