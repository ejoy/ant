local ecs   = ...
local world = ecs.world
local w     = world.w

local ImGui = require "imgui"
local ianimation    = ecs.require "ant.animation|animation"
local iplayback     = ecs.require "ant.animation|playback"
local irender       = ecs.require "ant.render|render"

local m = {}

function m.AnimationView(tags)
    local entities = tags['*']
    local names = {}
    for i = 1, #entities do
        local eid = entities[i]
        names[eid] = {}
    end
    for tag, list in pairs(tags) do
        if tag ~= '*' then
            for _, eid in ipairs(list) do
                table.insert(names[eid], tag)
            end
        end
    end
    for eid, list in pairs(names) do
        names[eid] = table.concat(list, "|")
    end
    if ImGui.Begin("entities", nil, ImGui.WindowFlags {"AlwaysAutoResize", "NoMove", "NoTitleBar"}) then
        local animation_eid
        if ImGui.TreeNode "mesh" then
            for i = 1, #entities do
                local eid = entities[i]
                local e <close> = world:entity(eid, "render_object?in animation?in visible?in")
                if e.render_object then
                    local value = { e.visible }
                    if ImGui.Checkbox(names[eid], value) then
                        irender.set_visible(e, value[1])
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

        if ImGui.TreeNodeEx("light", ImGui.TreeNodeFlags{"DefaultOpen"}) then
            local dl = w:first "directional_light light:in"
            if dl and ImGui.TreeNode "directional" then

                ImGui.TreePop()
            end

            local ible = w:first "ibl"
            local iibl = ecs.require "ant.render|ibl.ibl"
            if ible and ImGui.TreeNode "ibl" then

                local value = {iibl.get_ibl().intensity}
                if ImGui.SliderFloat("intensity", value, 1, 60000) then
                    iibl.set_ibl_intensity(value[1])
                end

                ImGui.TreePop()
            end

            ImGui.TreePop()
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
