local ecs = ...
local world = ecs.world

local imgui = require "imgui"
local ivs = ecs.require "ant.render|visible_state"
local iani = ecs.require "ant.animation|animation"

local m = ecs.system "main_system"

local entities

function m:init()
    local prefab = world:create_instance {
        prefab = "/pkg/vaststars.resources/glbs/miner-1.glb|work.prefab",
    }
    entities = prefab.tag['*']
end


function m:data_changed()
    if imgui.windows.Begin ("entities", imgui.flags.Window {"AlwaysAutoResize", "NoMove", "NoTitleBar"}) then
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
                local play = status.ratio ~= nil
                local change, _play = imgui.widget.Checkbox(name, play)
                if change then
                    if not _play then
                        iani.play(e, name)
                        goto continue
                    end
                    play = true
                    iani.play(e, name, 0)
                end
                if play then
                    local value = {
                        [1] = status.ratio,
                        min = 0,
                        max = 1,
                    }
                    if imgui.widget.SliderFloat("##"..name, value) then
                        local ratio = value[1]
                        iani.play(e, name, ratio)
                    end
                else
                end
                ::continue::
            end
            imgui.widget.TreePop()
        end
    end
    imgui.windows.End()
end
