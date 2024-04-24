local ecs   = ...
local world = ecs.world
local w     = world.w

local iani  = ecs.require "ant.animation|animation"

local m = ecs.system "animation_system"

function m:component_init()
    local animations = {}
    for e in w:select "INIT scene:in eid:in animation?update skinning?update animation_changed?out" do
        if e.animation ~= nil then
            local obj = iani.create(e.animation)
            e.animation = obj
            e.animation_changed = true
            animations[e.eid] = obj
        elseif e.scene.parent ~= 0 then
            local obj = animations[e.scene.parent]
            if obj then
                animations[e.eid] = obj
                if e.skinning ~= nil then
                    e.skinning = obj.skins[e.skinning]
                end
            end
        end
    end
end

function m:animation_sample()
    for e in w:select "animation_changed animation:in" do
        iani.sample(e)
    end
end

function m:final()
    w:clear "animation_changed"
end