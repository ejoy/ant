local ecs = ...
local world = ecs.world

local bgfx = require "bgfx"

local irender = world:interface "ant.render|irender"


local function can_write_depth(state)
	local s = bgfx.parse_state(state)
	local wm = s.WRITE_MASK
	return wm == nil or wm:match "Z"
end

local function which_material(eid)
	local pef = world:singleton_entity "pre_depth_queue"
	return world[eid].skinning_type == "GPU" and pef.pre_depth_skinning_material or pef.pre_depth_material
end


local s = ecs.system "pre_depth_primitive_system"
local w = world.w

local function sync_filter(mainkey, tag, layer)
    local r = {mainkey}
    for i = 1, #layer do
        r[#r+1] = tag .. "_" .. layer[i] .. "?out"
    end
    return table.concat(r, " ")
end

local function render_queue_update(v, rq, mainkey)
    local rc = v.render_object
    local fx = rc.fx
    local surfacetype = fx.setting.surfacetype
    if not rq.layer[surfacetype] then
        return
    end
    for i = 1, #rq.layer do
        v[rq.tag.."_"..rq.layer[i]] = false
    end
    v[rq.tag.."_"..surfacetype] = true
    w:sync(sync_filter(mainkey, rq.tag, rq.layer), v)
end

local function render_queue_del(v, rq, mainkey)
    for i = 1, #rq.layer do
        v[rq.tag.."_"..rq.layer[i]] = false
    end
    v[rq.tag] = false
    w:sync(sync_filter(mainkey, rq.tag, rq.layer), v)
end

function s:update_filter()
    for v in w:select "render_object_update render_object:in eid:in filter_material:in" do
        local rc = v.render_object
        local state = rc.entity_state
        for u in w:select "depth_filter render_queue:in" do
            local rq = u.render_queue
            local add = ((state & rq.mask) ~= 0) and ((state & rq.exclude_mask) == 0)
            if add and can_write_depth(rc.state) then
                render_queue_update(v, rq, "render_object_update")
				local mat = assert(which_material(v.eid))
                v.filter_material[rq.tag] = {
					properties	= mat.properties,
					fx			= mat.fx,
					state		= irender.check_primitive_mode_state(rc.state, mat.state),
				}
            else
                render_queue_del(v, rq, "render_object_update")
				v.filter_material[rq.tag] = nil
            end
        end
    end
end

function s:render_submit()
    for v in w:select "depth_filter visible render_queue:in" do
        local rq = v.render_queue
        local viewid = rq.viewid
        local CullTag = rq.tag.."_cull"
        for i = 1, #rq.layer do
            for u in w:select(rq.tag .. "_" .. rq.layer[i] .. " " .. CullTag .. " render_object:in filter_material:in") do
                irender.draw_mat(viewid, u.render_object, u.filter_material[rq.tag])
            end
        end
    end
end
