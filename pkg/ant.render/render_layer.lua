local ecs   = ...
local world = ecs.world
local w     = world.w

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

local irl = ecs.interface "irender_layer"

local function update_objects_layer()
    for e in w:select "render_layer:in render_object:update" do
        local idx = irl.layeridx(e.render_layer)
        e.render_object.render_layer = idx
    end
end

function irl.add_layers(after_layeridx, ...)
    local num_new_layers = select('#', ...)
    for i=1, num_new_layers do
        local n = #layer_names
        if #layer_names >= MAX_LAYER then
            error(("Too many render layer, max is :%d"):format(MAX_LAYER))
        end

        after_layeridx = after_layeridx or n
        if after_layeridx == MAX_LAYER then
            error "Can not push another layer, it will larger than MAX_LAYER"
        end

        layer_names[#layer_names+1] = select(i, ...)
    end

    if num_new_layers > 0 then
        update_objects_layer()
    end
end

function irl.remove_layer(layeridx)
    if layeridx <= 0 or layeridx > MAX_LAYER then
        log.warn(("Invalid layeridx:%d"):format(layeridx))
        return
    end

    table.remove(layer_names, layeridx)
    update_objects_layer()
end

function irl.layeridx(name)
    return find_layeridx(name)
end

function irl.layername(layeridx)
    return layer_names[layeridx]
end

function irl.set_layer(e, layername)
    w:extend(e, "render_layer:update render_object:update")
    local lidx = assert(irl.layeridx(layername), ("Invalid layer name:%s"):format(layername))
    e.render_layer = layername
    e.render_object.render_layer = lidx
    w:submit(e)
end
