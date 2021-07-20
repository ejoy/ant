local ecs = ...
local world = ecs.world

local ipf = ecs.interface "iprimitive_filter"

function ipf.select_filters(eid)
	world:pub {"sync_filter", eid}
end

function ipf.reset_filters(eid)
	world:pub {"sync_filter", eid}
end

local ies = world:interface "ant.scene|ientity_state"

local pf = ecs.component "primitive_filter"

function pf:init()
	self.filter_mask = ies.filter_mask(self.filter_type)
	self.exclude_mask = self.exclude_type and ies.filter_mask(self.exclude_type) or 0
	return self
end

local s = ecs.system "primitive_filter_system"
local w = world.w

local irender = world:interface "ant.render|irender"

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
    for v in w:select "render_object_update render_object:in" do
        local rc = v.render_object
        local state = rc.entity_state
        for u in w:select "primitive_filter render_queue:in" do
            local rq = u.render_queue
            local add = ((state & rq.mask) ~= 0) and ((state & rq.exclude_mask) == 0)
            if add then
                render_queue_update(v, rq, "render_object_update")
            else
                render_queue_del(v, rq, "render_object_update")
            end
        end
    end
end

function s:render_submit()
    for v in w:select "primitive_filter visible render_queue:in" do
        local rq = v.render_queue
        local viewid = rq.viewid
        local CullTag = rq.tag.."_cull"
        for i = 1, #rq.layer do
            for u in w:select(rq.tag .. "_" .. rq.layer[i] .. " " .. CullTag .. " render_object:in") do
                irender.draw(viewid, u.render_object)
            end
        end
    end
end
