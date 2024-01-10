local ecs   = ...
local world = ecs.world
local w     = world.w

local MAX_LAYER<const> = 64

local layer_names = {
    "foreground", "opacity", "background", "translucent", "decal", "ui"
}


local function build_opacity_layers()
    local layers = {}
    for _, ln in ipairs(layer_names) do
        if ln == "translucent" then
            break
        end
        layers[ln] = true
    end

    return layers
end

local opacity_layers = build_opacity_layers()

local function find_layeridx(name)
    for idx, ln in ipairs(layer_names) do
        if ln == name then
            return idx
        end
    end
end

local irl =  {}

local rl_mb = world:sub {"render_layer_changed"}

function irl.add_layers(after_layeridx, ...)
    local num_new_layers = select('#', ...)

    if num_new_layers > 0 then
        if (#layer_names + num_new_layers) > MAX_LAYER then
            error(("Not enough render layers to use, max is:%d"):format(MAX_LAYER))
        end

        local insertidx = after_layeridx or 0
        for i=1, num_new_layers do
            local name = select(i, ...)
            table.insert(layer_names, insertidx+i, name)
        end

        world:pub{"render_layer_changed"}
    end
end

function irl.remove_layer(layeridx)
    if layeridx <= 0 or layeridx > MAX_LAYER then
        log.warn(("Invalid layeridx:%d"):format(layeridx))
        return
    end

    table.remove(layer_names, layeridx)
    world:pub{"render_layer_changed"}
end

function irl.layeridx(name)
    return find_layeridx(name)
end

function irl.layername(layeridx)
    return layer_names[layeridx]
end

function irl.set_layer(e, layername)
    w:extend(e, "render_layer:update render_object:update")
    local lidx = irl.layeridx(layername) or error (("Invalid layer name:%s"):format(layername))
    e.render_layer = layername
    e.render_object.render_layer = lidx
    w:submit(e)
end

function irl.is_opacity_layer(layername)
    return opacity_layers[layername]
end

local rl_sys = ecs.system "render_layer_system"
function rl_sys:start_frame()
    for _ in rl_mb:unpack() do
        for e in w:select "render_layer:in render_object:update" do
            local idx = irl.layeridx(e.render_layer)
            e.render_object.render_layer = idx
        end

        opacity_layers = build_opacity_layers()
        break
    end
end

return irl
