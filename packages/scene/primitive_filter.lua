local ecs = ...
local world = ecs.world

local s = ecs.system "primitive_filter_system"
local w = world.w

local irender = world:interface "ant.render|irender"

local function sync_filter(mainkey, rq)
    local r = {mainkey}
    for i = 1, #rq.layer_tag do
        r[#r+1] = rq.layer_tag[i] .. "?out"
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
    for i = 1, #rq.layer_tag do
        v[rq.layer_tag[i]] = false
    end
    v[rq.tag.."_"..surfacetype] = true
    w:sync(sync_filter(mainkey, rq), v)
end

local function render_queue_del(v, rq, mainkey)
    for i = 1, #rq.layer_tag do
        v[rq.layer_tag[i]] = false
    end
    v[rq.tag] = false
    w:sync(sync_filter(mainkey, rq), v)
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
        for i = 1, #rq.layer_tag do
            for u in w:select(rq.layer_tag[i] .. " " .. rq.cull_tag .. " render_object:in") do
                irender.draw(viewid, u.render_object)
            end
        end
		w:clear(rq.cull_tag)
    end
end
