local ecs = ...
local world = ecs.world

local point2d = require "math.point2d"
local bgfx = require "bgfx"
local math3d = require "math3d"
local ru = require "render.util"
local mu = require "math.util"
local assetlib = require "asset"

-- pickup component
local pickup_comp = ecs.component "pickup" {    
    pick_buffer_w = 8,
    pick_buffer_h = 8,    
}

function pickup_comp:init()
    self.select_objlist = {}
    self.fb = 0

    self.blitdata = bgfx.memory_texture(self.pick_buffer_w*self.pick_buffer_h * 4)
end

local function add_pick_entity()
    local eid = world:new_entity("position", "direction", "frustum", "viewid", "pickup")
    local pickup_entity = assert(world[eid])
    pickup_entity.viewid.id = 1
    return pickup_entity
end

-- pickup helper
local pickup = {} 
pickup.__index = pickup

function pickup:init_material()
    self.material = assetlib["assets/assetfiles/materials/pickup.material"]
    local uniforms = assert(self.material.uniform, "pickup system need to define id uniform")
    local u_id = uniforms.u_id
    u_id.update = function ()
        assert(self.current_eid)
        return self.current_eid
    end
end

function pickup:init(pickup_entity)
    self:init_material()
    local comp = pickup_entity.pickup
    --[@ render hardware resource    
    local w, h = comp.pick_buffer_w, comp.pick_buffer_h
    comp.pick_buffer = bgfx.create_texture2d(w, h, false, 1, "RGBA8", "rt-p+p*pucvc")
    comp.pick_dbuffer = bgfx.create_texture2d(w, h, false, 1, "D24S8", "rt-p+p*pucvc")

    comp.pick_fb = bgfx.create_frame_buffer({comp.pick_buffer, comp.pick_dbuffer}, true)
    comp.rb_buffer = bgfx.create_texture2d(w, h, false, 1, "RGBA8", "bwbr-p+p*pucvc")

    local vid = pickup_entity.viewid.id
    bgfx.set_view_frame_buffer(vid, comp.pick_fb)
    bgfx.set_view_rect(vid, 0, 0, w, h)
    --@]
end

function pickup:render_to_pickup_buffer(pickup_entity)
    local vid = pickup_entity.viewid.id
    bgfx.touch(vid)

    ru.foreach_sceneobj(world, 
    function (entity, eid)
        assert(eid < 100000)
        self.current_eid = eid
        ru.draw_mesh(vid, entity.render.mesh, self.material, mu.srt_from_entity(self.ms, entity))
    end)
    self.current_eid = nil
end

function pickup:readback_render_data(pickup_entity)
    local pickup_blit_viewid = 2
    bgfx.touch(pickup_blit_viewid)

    local comp = pickup_entity.pickup
    
    bgfx.blit(pickup_blit_viewid, assert(comp.rb_buffer), 0, 0, assert(comp.pick_buffer))
    self.reading_frame = bgfx.read_texture(comp.rb_buffer, comp.blitdata)
end

function pickup:which_entity_hit(pickup_entity)
    local comp = pickup_entity.pickup
    local w, h = comp.pick_buffer_w, comp.pick_buffer_w

    for x = 1, w * h do
        local rgba = comp.blitdata[x]
        if rgba ~= 0 then
            return rgba
        end
    end
end

function pickup:pick(pickup_entity, need_readback, current_frame_num)
    self:render_to_pickup_buffer(pickup_entity)

    if need_readback then
        print("readback data")
        self:readback_render_data(pickup_entity)
    end

    if self.reading_frame == current_frame_num then
        print("try to found which hit")
        local comp = pickup_entity.pickup
        comp.last_eid_hit = self:which_entity_hit(pickup_entity)
        print("last eid : ", comp.last_eid_hit)
        self.reading_frame = nil
    end
end

-- update view system
-- separate this system from pickup_system is because the view info used in view_system
-- depend on this system to finish. we need a dependby method in ecs framework to make view_system know that 
-- it should depend this system
local pickup_view_update_sys = ecs.system "pickup_view"

pickup_view_update_sys.singleton "math_stack"
pickup_view_update_sys.singleton "viewport"
pickup_view_update_sys.singleton "message_component"

pickup_view_update_sys.depend "iup_message"
pickup_view_update_sys.depend "add_entities_system"

function pickup_view_update_sys:init()
    --[@    for message callback
    local msg = {}
    function msg:button(b, p, x, y)
        if b == "LEFT" and p then
            pickup.clickpt = point2d(x, y)
        end
    end
    local observers = self.message_component.msg_observers
    observers:add(msg)
    --@]

    local pickup_entity = add_pick_entity()

    pickup.ms = self.math_stack
    pickup:init(pickup_entity)
end

local function get_main_camera_viewproj_mat(ms)   
    for _, eid in world:each("main_camera") do 
        local me = world[eid]

        assert(me.position)
        assert(me.direction)
        assert(me.frustum)

        local proj = mu.proj(ms, me.frustum)

        -- there must be only one main camera
        return ms(proj, me.position.v, me.direction.v, "L*iP")
    end
end

local function extract_clickpt_to_eys_and_dir_in_worldspace(ms, clickpt, vp_w, wp_h, invVP)
    local ndcW =  (clickpt.x / vp_w) * 2.0 - 1.0
    local ndcH = ((vp_h - clickpt.y) / vp_h) * 2.0 - 1.0
    local eye = ms({ndcW, ndcH, 0, 1}, invVP, "*P")
    local at = ms({ndcW, ndcH, 1, 1}, invVP, "*P")
    local dir = ms(at, eye, "-nP")
    return eye, dir
end

local function update_pickup_entity_viewinfo(ms, e, clickpt, vp_w, vp_h)
    local invVP = get_main_camera_viewproj_mat(ms)    
    local ptWS, dirWS = nil, nil
    if clickpt then
        ptWS, dirWS = extract_clickpt_to_eys_and_dir_in_worldspace(ms, clickpt, vp_w, vp_h, invVP)
        assert(e.position)
        assert(e.direction)
        self.math_stack(e.position.v, assert(ptWS), "=")       
        self.math_stack(e.direction.v, assert(dirWS), "=")
    end
end

function pickup_view_update_sys:update()    
    print("pickup_view_update_sys:update()")
    local clickpt = pickup.clickpt
    if clickpt == nil then return end
    for _, eid in world:each("pickup") do        
        local e = assert(world[eid])
        if clickpt then
            local vp = self.viewport
            print("update pickup mat")
            update_pickup_entity_viewinfo(self.math_stack, e, clickpt, vp.width, vp.height)
        end
        break
    end   
end

-- system
local pickup_sys = ecs.system "pickup_system"

pickup_sys.singleton "math_stack"
pickup_sys.singleton "frame_num"

pickup_sys.depend "pickup_view"

function pickup_sys:update()
    print("function pickup_sys:update()")
    for _, eid in world:each("pickup") do
        local e = assert(world[eid])        
        local clickpt = pickup.clickpt
        pickup:pick(e, clickpt ~= nil, self.frame_num.current)
        break   --only one pickup object in the scene
    end

    pickup.clickpt = nil
end