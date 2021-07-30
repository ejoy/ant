local ecs = ...
local world = ecs.world
local w = world.w
local bgfx = require "bgfx"

local icamera = world:interface "ant.camera|camera"

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
local ies = world:interface "ant.scene|ientity_state"

local evCreateFilter = world:sub {"luaecs", "create_filter"}

local function findCamera(eid)
    local v = w:bsearch("eid", "eid", eid)
    if v then
        w:sync("camera_id:in", v)
        return v.camera_id
    end
end

local function render_queue_create(e)
    local viewid = e.render_target.viewid
    local camera_eid = e.camera_eid
    local visible = e.visible
    local filter = e.primitive_filter
    local type = filter.update_type
    local mask = ies.filter_mask(filter.filter_type)
    local exclude_mask = filter.exclude_type and ies.filter_mask(filter.exclude_type) or 0

    local layer = {}
    for i, n in ipairs(Layer[type]) do
        layer[i] = n
        layer[n] = i
    end

    local mgr = w:singleton "render_queue_manager"
    mgr.tag = mgr.tag + 1
    local tagname = "render" .. "_" .. mgr.tag
    local rq = {
        tag = tagname,
        cull_tag = tagname .. "_cull",
        layer_tag = {},
        mask = mask,
        exclude_mask = exclude_mask,
        layer = layer,
        viewid = viewid,
        camera_id = assert(findCamera(camera_eid), "not found camera"),
        update_queue = {},
    }
    register_tag(rq.tag)
    register_tag(rq.cull_tag)
    for i = 1, #layer do
        rq.layer_tag[i] = tagname .."_"..layer[i]
        register_tag(rq.layer_tag[i])
    end
    w:new {
        [type.."_filter"] = true,
        visible = visible,
        main_queue = e.main_queue,
        blit_queue = e.blit_queue,
        render_queue = rq
    }
end

function s:init()
    -- w:register {
    --     name = "render_queue",
    --     type = "lua",
    -- }
    -- register_tag "visible"
    -- register_tag "main_queue"
    -- register_tag "blit_queue"
    -- register_tag "primitive_filter"
    -- register_tag "pickup_filter"
    -- register_tag "shadow_filter"
    -- register_tag "depth_filter"
    -- create_singlton "render_queue_manager" {
    --     tag = 0
    -- }
end

function s:entity_init()
    --TODO
    -- for _, _, e in evCreateFilter:unpack() do
    --     render_queue_create(e)
    -- end
end

function s:end_filter()
    w:clear "render_object_update"
end

function s:render_submit()
    for v in w:select "visible camera_eid:in render_target:in" do
        local rt = v.render_target
        local viewid = rt.viewid
        local camera = icamera.find_camera(v.camera_eid)
        bgfx.touch(viewid)
        bgfx.set_view_transform(viewid, camera.viewmat, camera.projmat)
    end
end
