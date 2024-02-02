local ecs = ...
local world = ecs.world

local ImGui = import_package "ant.imgui"
local ivs = ecs.require "ant.render|visible_state"
local ianimation = ecs.require "ant.animation|animation"
local iplayback = ecs.require "ant.animation|playback"

local m = {}

function m.AnimationView(entities)
    if ImGui.Begin("entities", nil, ImGui.WindowFlags {"AlwaysAutoResize", "NoMove", "NoTitleBar"}) then
        local animation_eid
        if ImGui.TreeNode "mesh" then
            for i = 1, #entities do
                local eid = entities[i]
                local e <close> = world:entity(eid, "render_object?in animation?in")
                if e.render_object then
                    local value = { ivs.has_state(e, "main_view") }
                    if ImGui.Checkbox(""..eid, value) then
                        ivs.set_state(e, "main_view", value[1])
                        ivs.set_state(e, "cast_shadow", value[1])
                    end
                end
                if e.animation then
                    animation_eid = eid
                end
            end
            ImGui.TreePop()
        else
            for i = 1, #entities do
                local eid = entities[i]
                local e <close> = world:entity(eid, "animation?in")
                if e.animation then
                    animation_eid = eid
                end
            end
        end
        if animation_eid and ImGui.TreeNodeEx("animation", ImGui.TreeNodeFlags {"DefaultOpen"}) then
            local e <close> = world:entity(animation_eid, "animation:in")
            local animation = e.animation
            for name, status in pairs(animation.status) do
                if ImGui.TreeNode(name) then
                    do
                        local v = { status.play }
                        if ImGui.Checkbox("play", v) then
                            iplayback.set_play(e, name, v[1])
                        end
                    end
                    if ImGui.RadioButton("hide", iplayback.get_completion(e, name) == "hide") then
                        iplayback.completion_hide(e, name)
                    end
                    if ImGui.RadioButton("loop", iplayback.get_completion(e, name) == "loop") then
                        iplayback.completion_loop(e, name)
                    end
                    if ImGui.RadioButton("stop", iplayback.get_completion(e, name) == "stop") then
                        iplayback.completion_stop(e, name)
                    end
                    do
                        local value = { status.speed and math.floor(status.speed*100) or 100 }
                        if ImGui.DragIntEx("speed", value, 5.0, 0, 500, "%d%%") then
                            iplayback.set_speed(e, name, value[1] / 100)
                        end
                    end
                    do
                        local value = { status.weight }
                        if ImGui.SliderFloat("weight", value, 0, 1) then
                            ianimation.set_weight(e, name, value[1])
                        end
                    end
                    do
                        local value = { status.ratio }
                        if ImGui.SliderFloat("ratio", value, 0, 1) then
                            ianimation.set_ratio(e, name, value[1])
                        end
                    end
                    ImGui.TreePop()
                end
            end
            ImGui.TreePop()
        end
    end
    ImGui.End()
end

return m
