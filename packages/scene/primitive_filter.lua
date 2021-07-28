local ecs = ...
local world = ecs.world

local w = world.w

local LAYER_NAMES<const> = {"foreground", "opaticy", "background", "translucent", "decal", "ui"}

local LAYERS <const> = {
    main_queue = LAYER_NAMES,
    blit_queue = {
        "opaticy",
    },
    csm = {
        "opaticy", "translucent"
    },
    pickup_queue = {
        "opaticy", "translucent"
    },
    pre_depth_queue = {
        "opaticy"
    },
}

local FILTERS = {}
for k, q in pairs(LAYERS) do
    local f = {}
    for idx, n in ipairs(q) do
        f[idx] = n .. "_primitive_filter"
    end

    FILTERS[k] = f
end

local ipf = ecs.interface "iprimitive_filter"
function ipf.names()
    return LAYER_NAMES
end

function ipf.layers(filter_name)
    return assert(LAYERS[filter_name])
end

function ipf.filters(filter_name)
    return assert(FILTERS[filter_name])
end

function ipf.sync_filter(filter_name)
    local t = {}
    for _, n in ipairs(LAYERS[filter_name]) do
        t[#t+1] = n .. "?out"
    end

    return table.concat(t, ' ')
end

local function clear_tag(filter_name, o)
    local t = {}
	for _, n in ipairs(ipf.layers(filter_name)) do
		o[n] = false
        t = n .. "?out"
	end
    return table.concat(t, " ")
end

function ipf.update_filter_tag(filter_name, layername, layervalue, o)
    if layervalue == nil then
        error "should not be 'nil'"
    end
    local sf = clear_tag(filter_name)
    o[layername] = layervalue
	o[filter_name] = layervalue
    w:sync(sf, o)
end