local ecs = ...
local world = ecs.world
local w = world.w

local s = ecs.system "luaecs_filter_system"

local evCreate = world:sub {"component_register", "primitive_filter"}
local evUpdate = world:sub {"primitive_filter", "primitive"}

local Filter <const> = {
	"foreground", "opaticy", "background", "translucent", "decal", "ui"
}

local function sync_filter(tag)
    local r = {}
    for i = 1, #Filter do
        r[#r+1] = tag .. "_" .. Filter[i] .. "?out"
    end
    return table.concat(r, " ")
end

local function render_queue_create(e)
    local viewid = e.render_target.viewid
    local filter = e.primitive_filter
    local camera_eid = e.camera_eid

    local mgr = w:singleton "render_queue_manager"
    mgr.tag = mgr.tag + 1
    local tagname = "render" .. "_" .. mgr.tag
    w:register {
        name = tagname,
    }
    for i = 1, #Filter do
        w:register {
            name = tagname .."_"..Filter[i],
        }
    end
    w:new {
        render_queue = {
            tag = tagname,
            filter = filter,
            viewid = viewid,
            camera_eid = camera_eid,
            update_queue = {},
        }
    }
end

local function render_queue_add(rq, eid)
    local e = world[eid]
    local rc = e._rendercache
    local fx = rc.fx
    w:new {
        [rq.tag] = true,
        [rq.tag .."_"..fx.setting.surfacetype] = true,
        render_object = rc
    }
end

local function render_queue_update(rq, eid)
    local e = world[eid]
    local rc = e._rendercache
    local fx = rc.fx
    for v in w:select "eid:in" do
        if v.eid == eid then
            for i = 1, #Filter do
                v[rq.tag.."_"..Filter[i]] = false
            end
            v[rq.tag.."_"..fx.setting.surfacetype] = true
            w:sync(v, sync_filter(rq.tag))
            return
        end
    end
    render_queue_add(rq, eid)
end

local function render_queue_del(rq, eid)
    for v in w:select "eid:in" do
        if v.eid == eid then
            for i = 1, #Filter do
                v[rq.tag.."_"..Filter[i]] = false
            end
            v[rq.tag] = false
            w:sync(v, sync_filter(rq.tag))
            return
        end
    end
end

function s:init()
    w:register {
        name = "render_queue",
        type = "lua",
    }
    w:register {
        name = "render_object",
        type = "lua",
    }
    w:register {
        name = "render_queue_manager",
        type = "lua",
    }
    w:register {
        name = "eid",
        type = "int",
    }
    w:new {
        render_queue_manager = {
            tag = 0
        }
    }
end

function s:data_changed()
    for _,_, eid in evCreate:unpack() do
        local e = world[eid]
        render_queue_create(e)
    end
end

function s:update_filter()
    for _, _, what, eid in evUpdate:unpack() do
        local e = world[eid]
        local rc = e._rendercache
        local state = rc.entity_state
        if state == nil or rc.fx == nil then
            goto continue
        end
        local needadd = rc.vb and rc.fx and rc.state
        for v in w:select "render_queue:in" do
            local rq = v.render_queue
            local filter = rq.filter
            local add = needadd and ((state & filter.filter_mask) ~= 0) and ((state & filter.exclude_mask) == 0)
            if filter.update_type == "primitive" then
                if add then
                    if what ~= "del" then
                        render_queue_update(rq, eid)
                    end
                else
                    if what ~= "add" then
                        render_queue_del(rq, eid)
                    end
                end
            end
        end
        ::continue::
    end
end

local irender = world:interface "ant.render|irender"
local bgfx = require "bgfx"

function s:render_submit()
    for v in w:select "render_queue:in" do
        local rq = v.render_queue
        local viewid = rq.viewid
        local camera = world[rq.camera_eid]._rendercache
        bgfx.touch(viewid)
        bgfx.set_view_transform(viewid, camera.viewmat, camera.projmat)
        for i = 1, #Filter do
            for u in w:select(rq.tag .. "_" .. Filter[i] .. " render_object:in") do
                irender.draw(viewid, u.render_object)
            end
        end
    end
end
