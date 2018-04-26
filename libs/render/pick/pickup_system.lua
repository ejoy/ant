local ecs = ...
local world = ecs.world

local point2d = require "math.point2d"
local bgfx = require "bgfx"
local math3d = require "math3d"
local ru = require "render.util"
local mu = require "math.util"
local asset = require "asset"
local shadermgr = require "render.resources.shader_mgr"

-- pickup component
ecs.component "pickup"{}

-- pickup helper
local pickup = {} 
pickup.__index = pickup

local function packeid_as_rgba(eid)
    return {(eid & 0x000000ff) / 0xff,
            ((eid & 0x0000ff00) >> 8) / 0xff,
            ((eid & 0x00ff0000) >> 16) / 0xff,
            ((eid & 0xff000000) >> 24) / 0xff}    -- rgba
end

local function unpackrgba_to_eid(rgba)
    local r =  rgba & 0x000000ff
    local g = (rgba & 0x0000ff00) >> 8
    local b = (rgba & 0x00ff0000) >> 16
    local a = (rgba & 0xff000000) >> 24
    
    return r + g + b + a
end

function pickup:init_material()
    local mname = "pickup.material"
    self.material = asset.load(mname) 
    self.material.name = mname
end

local function bind_frame_buffer(e)
    local comp = e.pickup    
    local vid = e.viewid.id
    bgfx.set_view_frame_buffer(vid, assert(comp.pick_fb))
end

function pickup:init(pickup_entity)
    self:init_material()
    local comp = pickup_entity.pickup
    --[@ init hardware resource
    local vr = pickup_entity.view_rect
    local w, h = vr.w, vr.h
    comp.pick_buffer = bgfx.create_texture2d(w, h, false, 1, "RGBA8", "rt-p+p*pucvc")
    comp.pick_dbuffer = bgfx.create_texture2d(w, h, false, 1, "D24S8", "rt-p+p*pucvc")

    comp.pick_fb = bgfx.create_frame_buffer({comp.pick_buffer, comp.pick_dbuffer}, true)
    comp.rb_buffer = bgfx.create_texture2d(w, h, false, 1, "RGBA8", "bwbr-p+p*pucvc")
    --@]

    bind_frame_buffer(pickup_entity)
end

local function create_pickup_render_entity(entity, eid, pu_material, ms)
    local visible = entity.render.visible
    if not visible then
        return nil
    end
    
    local info = {}
    local uid_setter = shadermgr.create_uniform_setter("u_id", ms(packeid_as_rgba(eid), "m"))
    local uniforms = {}
    for _, elem in ipairs(entity.render.info) do
        local mesh = elem.mesh
        local mgroups = mesh.handle.group
        local meshids = {}
        local num = #mgroups
        for i=1, num do
            table.insert(meshids, i)
        end
        table.insert(info, {mesh=mesh, binding={{material=pu_material, meshids=meshids}}, srt=elem.srt})
        table.insert(uniforms, {uid_setter})
    end

    return { 
        render = {
            info=info, 
            uniforms=uniforms, 
            visible=true
        }, 
        scale=assert(entity.scale), 
        rotation=assert(entity.rotation), 
        position=assert(entity.position), 
        name=entity.name
    }
end

local db = require "debugger"

function pickup:render_to_pickup_buffer(pickup_entity)    
    for _, eid in world:each("can_select") do        
        local entity = assert(world[eid])
        local e = create_pickup_render_entity(entity, eid, self.material, self.ms)
        if e then                        
            ru.draw_entity(pickup_entity.viewid.id, e, self.ms)            
        end
    end
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
    local vr = pickup_entity.view_rect
    local w, h = vr.w, vr.h

    for x = 1, w * h do
        local rgba = comp.blitdata[x]
        if rgba ~= 0 then            
            local eid = unpackrgba_to_eid(rgba)
            return eid
        end
    end
    return nil
end

function pickup:pick(p_eid, current_frame_num)
    local pickup_entity = world[p_eid]
    if self.reading_frame == nil then        
        bind_frame_buffer(pickup_entity)
        self:render_to_pickup_buffer(pickup_entity)
        self.reading_frame = self:readback_render_data(pickup_entity)        
    end

    if self.reading_frame == current_frame_num then
        local comp = pickup_entity.pickup
        local eid = self:which_entity_hitted(pickup_entity)
        if eid then
            local name = assert(world[eid]).name.n
            print("pick entity id : ", eid, ", name : ", name)
        else
            print("not found any eid")
        end

        comp.last_eid_hit = eid
        world:change_component(p_eid, "pickup")
        world.notify()
        self.reading_frame = nil
    end
    self.is_picking = self.reading_frame ~= nil
end

-- pickup view
local pickup_view_sys = ecs.system "pickup_view"

pickup_view_sys.singleton "math_stack"
pickup_view_sys.singleton "message_component"

pickup_view_sys.depend "iup_message"
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

local function get_main_camera_viewproj_mat(ms, maincamera)      
    local proj = mu.proj(ms, assert(maincamera.frustum))
    -- [pos, dir] ==> viewmat --> viewmat * projmat ==> viewprojmat
    -- --> invert(viewprojmat) ==>invViewProjMat
    local dir = ms(assert(maincamera.rotation).v, "dP")
    return ms(assert(maincamera.position).v, dir, "L", proj, "*iP")
end

local function click_to_eye_and_dir(ms, ndcX, ndcY, invVP)    
    local eye = ms({ndcX, ndcY, 0, 1}, invVP, "%P")
    local at = ms({ndcX, ndcY, 1, 1}, invVP, "%P")
    local dir = ms(at, eye, "-nP")
    return eye, dir
end

local function update_viewinfo(ms, e, clickpt)    
    local maincamera = world:first_entity("main_camera")  
    local invVP = get_main_camera_viewproj_mat(ms, maincamera)

    local mc_vr = maincamera.view_rect

    local w, h = mc_vr.w, mc_vr.h
    local ndcX =  (clickpt.x / w) * 2.0 - 1.0
    local ndcY = ((h - clickpt.y) / h) * 2.0 - 1.0

    local ptWS, dirWS = click_to_eye_and_dir(ms, ndcX, ndcY, invVP)    
    ms(assert(e.position).v, assert(ptWS),     "=")
    ms(assert(e.rotation).v, dirWS, "D=")
end

function pickup_view_sys:update()
    local clickpt = pickup.clickpt
    if clickpt ~= nil then
        local pu_entity = world:first_entity("pickup")        
        update_viewinfo(self.math_stack, pu_entity, clickpt)

        pickup.is_picking = true
        pickup.clickpt = nil
    end
end

-- system
local pickup_sys = ecs.system "pickup_system"

pickup_sys.singleton "math_stack"
pickup_sys.singleton "frame_stat"

pickup_sys.depend "pickup_view"
pickup_sys.dependby "end_frame"

function pickup_sys:init()
    local function add_pick_entity(ms)
        local eid = world:new_entity("pickup", "viewid", "position", "rotation", "frustum", "view_rect", "clear_component", "name")        
        local entity = assert(world[eid])
        entity.viewid.id = 1
        entity.name.n = "pickup"

        local cc = entity.clear_component
        cc.color = 0

        local vr = entity.view_rect
        vr.w = 8
        vr.h = 8
    
        local comp = entity.pickup
        comp.blitdata = bgfx.memory_texture(vr.w*vr.h * 4)

        local frustum = entity.frustum
        mu.frustum_from_fov(frustum, 0.1, 100, 1, vr.w / vr.h)
        
        local pos = entity.position.v
        local rot = entity.rotation.v
        ms(pos, {0, 0, 0, 1}, "=")
        ms(rot, {0, 0, 0, 0}, "=")
        
        return entity
    end

    local entity = add_pick_entity(self.math_stack)

    pickup.ms = self.math_stack
    pickup:init(entity)
end

function pickup_sys:update()
    if pickup.is_picking then        
        local eid = assert(world:first_entity_id("pickup"))    
        pickup:pick(eid, self.frame_stat.frame_num)
    end
end

