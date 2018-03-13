local ecs = ...
local world = ecs.world

local point2d = require "math.point2d"
local bgfx = require "bgfx"
local math3d = require "math3d"
local ru = require "render.util"

-- pickup component
local pickup_comp = ecs.component "pickup" {    
    pick_buffer_w = 8,
    pick_buffer_h = 8,    
}

function pickup_comp:init()
    self.select_objlist = {}
    self.fb = 0
end

local function add_pick_entity()
    local eid = world:new_entity("position", "direction", "frustum", "viewid", "pickup")
    local pickup = assert(world[eid])
    pickup.viewid.id = 1
end

-- system
local pickup_sys = ecs.system "pickup_system"

pickup_sys.singleton "math_stack"
pickup_sys.singleton "message_component"
pickup_sys.singleton "viewport"

pickup_sys.depend "iup_message"
pickup_sys.depend "add_entities_system"

local pickup = {} 
pickup.__index = pickup

function pickup:init_material()
    local material = self.material
    if type(material.shader) == "string" then
        error "materil not default init"
    end

    local uniforms = material.uniforms
    local uid = uniforms.u_id
    assert(uid ~= nil)

    uid.update = function()
        self.pickid = self.pickid + 1
        return self.pickid
    end
end

function pickup:init()
    self.pickid = 0

    self:init_material()

    --[@ render hardware resource
    local comp = self.comp
    local w, h = comp.pick_buffer_w, comp.pick_buffer_h
    local pick_buffer = bgfx.create_texture2d(w, h, false, 1, "RGBA8", "rt-p+p*pucvc")
    local pick_dbuffer = bgfx.create_texture2d(w, h, false, 1, "D24S8", "rt-p+p*pucvc")

    comp.pick_fb = bgfx.create_frame_buffer({pick_buffer, pick_dbuffer}, true)
    comp.rb_buffer = bgfx.create_texture2d(w, h, false, 1, "RGBA8", "bwbr-p+p*pucvc")

    bgfx.set_view_frame_buffer(comp.pick_viewid, comp.pick_fb)
    --@]
end

function pickup:render_to_pickup_buffer(pickup_entity)
    local comp = self.pickup_comp
    bgfx.set_view_frame_buffer(comp.pick_viewid, comp.pick_fb)
    bgfx.touch(pickup_entity.viewid.id)

    ru.foreach_sceneobj(world, 
    function (entity)
        bgfx.set_transform(~entity.worldmat_comp.mat)
        
        local material = self.material
        bgfx.set_state(bgfx.make_state(material.state))

        ru.update_uniforms(material.uniforms)
        ru.submit_mesh(entity.mesh.handle, material.shader)
    end)
end

function pickup:readback_render_data()
    
end

function pickup:pick_object(objlist, clickpt, selectrange)
    
end

function pickup:pick()
    
end

function pickup_sys:init()
    --[@    for message callback
    local msg = {}
    function msg:button(x, y)
        pickup_sys.clickpt = point2d(x, y)
    end
    local observers = self.message_component.msg_observers
    observers:add(msg)
    --@]

    add_pick_entity()

    pickup.comp = self.pu_comp
    pickup.ms = self.math_stack        
    pickup:init(self.pickup, 8, 8)
end

function pickup_sys:update()
    ru.foreach_entity(world, {"pickup", "position", "direction", "frustum"},
    function (entity)
        local clickpt = self.clickpt
        if clickpt then
            pickup:pick(entity, clickpt)
        end
    end
    )


end