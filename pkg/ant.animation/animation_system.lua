local ecs   = ...
local world = ecs.world
local w     = world.w

local iani  = ecs.require "ant.animation|animation"

local m = ecs.system "animation_system"

function m:component_init()
    for e in w:select "INIT animation:update animation_changed?out" do
        local obj = iani.create(e.animation)
        e.animation = obj
        e.animation_changed = true
    end
    for e in w:select "INIT skinning:update eid:in" do
        local eid = e.skinning.animation
        local obj = w:fetch(eid, "animation:in").animation
        e.skinning = obj.skins[e.skinning.skin]
    end
end

function m:animation_sample()
    iani.frame()
    for e in w:select "animation_changed animation:in" do
        iani.sample(e)
    end
end

function m:final()
    w:clear "animation_changed"
end