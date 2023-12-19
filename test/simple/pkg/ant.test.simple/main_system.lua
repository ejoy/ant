local ecs = ...
local world = ecs.world
local w = world.w

local imgui = require "imgui"
local ivs = ecs.require "ant.render|visible_state"
local ianimation = ecs.require "ant.animation|animation"
local iplayback = ecs.require "ant.animation|playback"

local m = ecs.system "main_system"

local entities

function m:init()
    local prefab = world:create_instance {
        prefab = "/pkg/vaststars.resources/glbs/miner-1.glb|work.prefab",
    }
    entities = prefab.tag['*']
end

function m:data_changed()
    if imgui.windows.Begin("entities", imgui.flags.Window {"AlwaysAutoResize", "NoMove", "NoTitleBar"}) then
        local animation_eid
        if imgui.widget.TreeNode "mesh" then
            for i = 1, #entities do
                local eid = entities[i]
                local e <close> = world:entity(eid, "render_object?in animation?in")
                if e.render_object then
                    local v = ivs.has_state(e, "main_view")
                    local change, value = imgui.widget.Checkbox(""..eid, v)
                    if change then
                        ivs.set_state(e, "main_view", value)
                    end
                end
                if e.animation then
                    animation_eid = eid
                end
            end
            imgui.widget.TreePop()
        else
            for i = 1, #entities do
                local eid = entities[i]
                local e <close> = world:entity(eid, "animation?in")
                if e.animation then
                    animation_eid = eid
                end
            end
        end
        if animation_eid and imgui.widget.TreeNode "animation" then
            local e <close> = world:entity(animation_eid, "animation:in")
            local animation = e.animation
            for name, status in pairs(animation.status) do
                if imgui.widget.TreeNode(name) then
                    do
                        local change, v = imgui.widget.Checkbox("play", status.play)
                        if change then
                            iplayback.play(e, name, {
                                play = v,
                                loop = status.loop,
                            })
                        end
                    end
                    do
                        local change, v = imgui.widget.Checkbox("loop", status.loop)
                        if change then
                            iplayback.play(e, name, {
                                loop = v,
                                play = status.play,
                            })
                        end
                    end
                    do
                        local change, v = imgui.widget.Checkbox("sample", status.weight > 0)
                        if change then
                            if v then
                                ianimation.set_weight(e, name, 1)
                            else
                                ianimation.set_weight(e, name, 0)
                            end
                        end
                    end
                    local value = {
                        [1] = status.ratio,
                        min = 0,
                        max = 1,
                    }
                    if imgui.widget.SliderFloat("##"..name, value) then
                        local ratio = value[1]
                        ianimation.set_ratio(e, name, ratio)
                    end
                    imgui.widget.TreePop()
                end
            end
            imgui.widget.TreePop()
        end
    end
    imgui.windows.End()
end
