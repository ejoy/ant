local ecs = ...
local world = ecs.world
local w = world.w

local function create_singlton(name)
    return function (value)
        w:register {
            name = name,
            type = "lua",
        }
        w:new {
            [name] = value
        }
    end
end

local function register_tag(name)
    w:register {
        name = name,
    }
end

local s = ecs.system "luaecs_filter_system"

local evCreate = world:sub {"component_register", "primitive_filter"}
local evUpdate = world:sub {"primitive_filter", "primitive"}

local Layer <const> = {
    primitive = {
        "foreground", "opaticy", "background", "translucent", "decal", "ui"
    },
    shadow = {
        "opaticy", "translucent"
    },
    pickup = {
        "opaticy", "translucent"
    },
    depth = {
        "opaticy"
    },
}

local function sync_filter(tag, layer)
    local r = {}
    for i = 1, #layer do
        r[#r+1] = tag .. "_" .. layer[i] .. "?out"
    end
    return table.concat(r, " ")
end

local function render_queue_create(e)
    local viewid = e.render_target.viewid
    local filter = e.primitive_filter
    local camera_eid = e.camera_eid
    local filter_type = filter.update_type
    local layer = {}
    for i, n in ipairs(Layer[filter_type]) do
        layer[i] = n
        layer[n] = i
    end

    local mgr = w:singleton "render_queue_manager"
    mgr.tag = mgr.tag + 1
    local tagname = "render" .. "_" .. mgr.tag
    w:register {
        name = tagname,
    }
    for i = 1, #layer do
        w:register {
            name = tagname .."_"..layer[i],
        }
    end
    w:new {
        [filter_type.."_filter"] = true,
        render_queue = {
            tag = tagname,
            filter = filter,
            layer = layer,
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
    local surfacetype = fx.setting.surfacetype
    if not rq.layer[surfacetype] then
        return
    end
    w:new {
        [rq.tag] = true,
        [rq.tag .."_"..surfacetype] = true,
        render_object = rc
    }
end

local function render_queue_update(rq, eid)
    local e = world[eid]
    local rc = e._rendercache
    local fx = rc.fx
    local surfacetype = fx.setting.surfacetype
    if not rq.layer[surfacetype] then
        return
    end
    for v in w:select "eid:in" do
        if v.eid == eid then
            for i = 1, #rq.layer do
                v[rq.tag.."_"..rq.layer[i]] = false
            end
            v[rq.tag.."_"..surfacetype] = true
            w:sync(v, sync_filter(rq.tag, rq.layer))
            return
        end
    end
    render_queue_add(rq, eid)
end

local function render_queue_del(rq, eid)
    for v in w:select "eid:in" do
        if v.eid == eid then
            for i = 1, #rq.layer do
                v[rq.tag.."_"..rq.layer[i]] = false
            end
            v[rq.tag] = false
            w:sync(v, sync_filter(rq.tag, rq.layer))
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
        name = "eid",
        type = "int",
    }
    register_tag "primitive_filter"
    register_tag "pickup_filter"
    register_tag "shadow_filter"
    register_tag "depth_filter"
    create_singlton "render_queue_manager" {
        tag = 0
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
        ::continue::
    end
end

local irender = world:interface "ant.render|irender"
local bgfx = require "bgfx"

function s:render_submit()
    for v in w:select "primitive_filter render_queue:in" do
        local rq = v.render_queue
        local viewid = rq.viewid
        local camera = world[rq.camera_eid]._rendercache
        bgfx.touch(viewid)
        bgfx.set_view_transform(viewid, camera.viewmat, camera.projmat)
        for i = 1, #rq.layer do
            for u in w:select(rq.tag .. "_" .. rq.layer[i] .. " render_object:in") do
                irender.draw(viewid, u.render_object)
            end
        end
    end
end
