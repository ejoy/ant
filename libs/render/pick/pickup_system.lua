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
    width = 8,
    height = 8,
}

function pickup_comp:init()    
    self.blitdata = bgfx.memory_texture(self.width*self.height * 4)
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

local function update_view_state(pickup_entity)
    local comp = pickup_entity.pickup

    local vid = pickup_entity.viewid.id
    bgfx.set_view_frame_buffer(vid, assert(comp.pick_fb))
    bgfx.set_view_rect(vid, 0, 0, comp.width, comp.height)
end

function pickup:init(pickup_entity)
    self:init_material()
    local comp = pickup_entity.pickup
    --[@ init hardware resource
    local w, h = comp.width, comp.height
    comp.pick_buffer = bgfx.create_texture2d(w, h, false, 1, "RGBA8", "rt-p+p*pucvc")
    comp.pick_dbuffer = bgfx.create_texture2d(w, h, false, 1, "D24S8", "rt-p+p*pucvc")

    comp.pick_fb = bgfx.create_frame_buffer({comp.pick_buffer, comp.pick_dbuffer}, true)
    comp.rb_buffer = bgfx.create_texture2d(w, h, false, 1, "RGBA8", "bwbr-p+p*pucvc")
    --@]

    update_view_state(pickup_entity)
end

function pickup:render_to_pickup_buffer(pickup_entity)    
    ru.foreach_sceneobj(world, 
    function (entity, eid)
        self.current_eid = eid
        ru.draw_mesh(pickup_entity.viewid.id, entity.render.mesh, self.material, mu.srt_from_entity(self.ms, entity))
    end)
    self.current_eid = nil
end

function pickup:readback_render_data(pickup_entity)
    local pickup_blit_viewid = 2
    local comp = pickup_entity.pickup
    
    bgfx.blit(pickup_blit_viewid, assert(comp.rb_buffer), 0, 0, assert(comp.pick_buffer))
    assert(self.reading_frame == nil)
    return bgfx.read_texture(comp.rb_buffer, comp.blitdata)
end

function pickup:which_entity_hitted(pickup_entity)
    local comp = pickup_entity.pickup
    local w, h = comp.width, comp.width

    for x = 1, w * h do
        local rgba = comp.blitdata[x]
        if rgba ~= 0 then            
            return rgba
        end
    end
end

local function clear_buffer(id)
    bgfx.set_view_clear(id, "CD", 0x00000000, 1, 0)	
end

function pickup:pick(pickup_entity, current_frame_num)
    clear_buffer(pickup_entity.viewid.id)
    update_view_state(pickup_entity)
    self:render_to_pickup_buffer(pickup_entity)

    if self.reading_frame == nil then
        self.reading_frame = self:readback_render_data(pickup_entity)        
    end

    if self.reading_frame == current_frame_num then
        local comp = pickup_entity.pickup
        local eid = self:which_entity_hitted(pickup_entity)
        if eid then
            print("pick entity id : ", eid)
            comp.last_eid_hit = eid
        else
            print("not found any eid")
        end
        self.reading_frame = nil
    end
    self.is_picking = self.reading_frame ~= nil
end

local pickup_view_sys = ecs.system "pickup_view"

pickup_view_sys.singleton "math_stack"
pickup_view_sys.singleton "viewport"
pickup_view_sys.singleton "message_component"

pickup_view_sys.depend "iup_message"
pickup_view_sys.depend "add_entities_system"
pickup_view_sys.dependby "view_system"

function pickup_view_sys:init()
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
end

local function get_main_camera_viewproj_mat(ms)   
    for _, eid in world:each("main_camera") do 
        local me = world[eid]
        local proj = mu.proj(ms, assert(me.frustum))
        -- [pos, dir] ==> viewmat --> viewmat * projmat ==> viewprojmat
        -- --> invert(viewprojmat) ==>invViewProjMat
        return ms(assert(me.position).v, assert(me.direction).v, "L", proj, "*iP")  
    end
end

local function click_to_eye_and_dir(ms, clickpt, vp_w, vp_h, invVP)    
    local ndcX =  (clickpt.x / vp_w) * 2.0 - 1.0
    local ndcY = ((vp_h - clickpt.y) / vp_h) * 2.0 - 1.0

    local eye = ms({ndcX, ndcY, 0, 1}, invVP, "%P")
    local at = ms({ndcX, ndcY, 1, 1}, invVP, "%P")
    local dir = ms(at, eye, "-nP")
    return eye, dir
end

local function update_viewinfo(ms, e, clickpt, vp_w, vp_h)
    local invVP = get_main_camera_viewproj_mat(ms)    
    local ptWS, dirWS = click_to_eye_and_dir(ms, clickpt, vp_w, vp_h, invVP)
    ms( assert(e.position).v, assert(ptWS),     "=", 
        assert(e.direction).v, assert(dirWS),   "=")
end

function pickup_view_sys:update()
    local clickpt = pickup.clickpt
    if clickpt ~= nil then
        for _, eid in world:each("pickup") do                
            local vp = self.viewport
            update_viewinfo(self.math_stack, assert(world[eid]), clickpt, vp.width, vp.height)
            break
        end
        pickup.is_picking = true
        pickup.clickpt = nil
    end
end

-- system
local pickup_sys = ecs.system "pickup_system"

pickup_sys.singleton "math_stack"
pickup_sys.singleton "frame_num"

pickup_sys.depend "pickup_view"
pickup_sys.dependby "end_frame"

function pickup_sys:init()
    local function add_pick_entity(ms)
        local eid = world:new_entity("position", "direction", "frustum", "viewid", "pickup")
        local pickup_entity = assert(world[eid])
        pickup_entity.viewid.id = 1
    
        local comp = pickup_entity.pickup
        local frustum = pickup_entity.frustum
        mu.frustum_from_fov(frustum, 0.1, 100, 1, comp.width / comp.height)
        
        local pos = pickup_entity.position.v
        local dir = pickup_entity.direction.v
        ms(pos, {0, 0, 0, 1}, "=")
        ms(dir, {0, 0, 1, 0}, "=")
        
        return pickup_entity
    end

    local pickup_entity = add_pick_entity(self.math_stack)

    pickup.ms = self.math_stack
    pickup:init(pickup_entity)
end

function pickup_sys:update()
    if pickup.is_picking then        
        for _, eid in world:each("pickup") do
            local e = assert(world[eid])
            pickup:pick(e, self.frame_num.current)
            break   --only one pickup object in the scene
        end
    end
end