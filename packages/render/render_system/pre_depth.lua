local ecs = ...
local world = ecs.world

local bgfx = require "bgfx"

local irender   = world:interface "ant.render|irender"
local ipf       = world:interface "ant.scene|iprimitive_filter"

local function can_write_depth(state)
	local s = bgfx.parse_state(state)
	local wm = s.WRITE_MASK
	return wm == nil or wm:match "Z"
end


local pre_depth_material
local pre_depth_skinning_material

local function which_material(eid)
	return world[eid].skinning_type == "GPU" and pre_depth_skinning_material or pre_depth_material
end


local s = ecs.system "pre_depth_primitive_system"
local w = world.w

local function sync_filter(rq)
    local r = {}
    for i = 1, #rq.layer_tag do
        r[#r+1] = rq.layer_tag[i] .. "?out"
    end
    return table.concat(r, " ")
end

local function render_queue_update(v, rq)
    local rc = v.render_object
    local fx = rc.fx
    local surfacetype = fx.setting.surfacetype
    if not rq.layer[surfacetype] then
        return
    end
    for i = 1, #rq.layer_tag do
        v[rq.layer_tag[i]] = false
    end
    v[rq.tag.."_"..surfacetype] = true
    w:sync(sync_filter(rq), v)
end

local function render_queue_del(v, rq)
    for i = 1, #rq.layer_tag do
        v[rq.layer_tag[i]] = false
    end
    v[rq.tag] = false
    w:sync(sync_filter(rq), v)
end

function s:init()
    local pre_depth_material_file<const> 	= "/pkg/ant.resources/materials/predepth.material"
    pre_depth_material 			= imaterial.load(pre_depth_material_file, {depth_type="linear"})
    pre_depth_skinning_material = imaterial.load(pre_depth_material_file, {depth_type="linear", skinning="GPU"})
end

function s:update_filter()
    for v in w:select "render_object_update render_object:in eid:in filter_material:in" do
        local rc = v.render_object
        local st = rc.fx.setting.surfacetype
        local state = rc.entity_state
        local render_state = rc.state
        local eid = v.eid
        for vv in w:select(st .. " pre_depth_queue primitive_filter:in") do
            local pf = vv.primitive_filter
            local mask = ies.filter_mask(pf.filter_type)
            local exclude_mask = pf.exclude_type and ies.filter_mask(pf.exclude_type) or 0

            local add = ((state & mask) ~= 0) and 
                        ((state & exclude_mask) == 0) and
                        can_write_depth(render_state)

            ipf.update_filter_tag("pre_depth_queue", st, add, v)

            local m = assert(which_material(eid))
            v.filter_material[st] = add and {
                fx          = m.fx,
                properties  = m.properties,
                state       = irender.check_primitive_mode_state(rc.state, m.state),
            } or nil
        end
    end
end

function s:render_submit()
    for v in w:select "pre_depth_queue visible render_target:in" do
        local viewid = v.render_target.viewid
        for _, ln in ipairs(ipf.layers "pre_depth_queue") do
            for u in w:select(ln .. " pre_depth_queue_cull:absent render_object:in filter_material:in") do
                irender.draw(viewid, u.render_object, u.filter_material[ln])
            end
            w:clear "pre_depth_queue_cull"
        end
    end
end
