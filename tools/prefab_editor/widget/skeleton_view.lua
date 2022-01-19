local ecs = ...
local world = ecs.world
local w = world.w

local imgui     = require "imgui"
local uiconfig  = require "widget.config"
local uiutils   = require "widget.utils"
local joint_utils  = require "widget.joint_utils"

local m = {}

local joints

local bone_anim = {
    dirty = true,
    dirty_layer = -1,-- [1...n]: dirty index, 0: no dirty, -1: all dirty
    duration = 1.6,
    is_playing = false,
    selected_layer_index = -1,
    selected_frame = -1,
    current_frame = 0,
    clip_range_dirty = 0,
    selected_clip_index = 0,
    anims = {}
}

local anim_state = {
    
}

local function new_bone_anim(name, clips)
    bone_anim.anims[#bone_anim.anims + 1] = {
        bone_name = name,
        clips = clips
    }
end

new_bone_anim("bone0", {})
new_bone_anim("bone1", { { name = "clip0", range = {10, 20} }, { name = "clip1", range = {40, 65} } })
new_bone_anim("bone2", {})
new_bone_anim("bone3", { { name = "clip0", range = {30, 60} } })
new_bone_anim("bone4", {})

local sample_ratio = 50.0
local function min_max_range_value(clip_index)
    return 0, math.ceil(bone_anim.duration * sample_ratio) - 1
end

local imgui_message = {}
local function on_move_clip(move_type, current_clip_index, move_delta)
    local clips = bone_anim.clips
    if current_clip_index <= 0 or current_clip_index > #clips then return end
    local clip = clips[current_clip_index]
    if not clip then return end
    local min_value, max_value = min_max_range_value(current_clip_index)
    if move_type == 1 then
        local new_value = clip.range[1] + move_delta
        if new_value < 0 then
            new_value = 0
        end
        if new_value > clip.range[2] then
            new_value = clip.range[2]
        end
        clip.range[1] = new_value
        --clip.range_ui[1] = clip.range[1]
    elseif move_type == 2 then
        local new_value = clip.range[2] + move_delta
        if new_value < clip.range[1] then
            new_value = clip.range[1]
        end
        if new_value > max_value then
            new_value = max_value
        end
        clip.range[2] = new_value
        --clip.range_ui[2] = clip.range[2]
    elseif move_type == 3 then
        local new_value1 = clip.range[1] + move_delta
        local new_value2 = clip.range[2] + move_delta
        if new_value1 >= min_value and new_value2 <= max_value then
            clip.range[1] = new_value1
            clip.range[2] = new_value2
            --clip.range_ui[1] = clip.range[1]
            --clip.range_ui[2] = clip.range[2]
        end
    end
    --set_clips_dirty(true)
    anim_state.clip_range_dirty = 1
end

function m.show()
    do return end
    local viewport = imgui.GetMainViewport()
    imgui.windows.SetNextWindowPos(viewport.WorkPos[1], viewport.WorkPos[2] + viewport.WorkSize[2] - uiconfig.BottomWidgetHeight, 'F')
    imgui.windows.SetNextWindowSize(viewport.WorkSize[1], uiconfig.BottomWidgetHeight, 'F')
    for _ in uiutils.imgui_windows("Skeleton", imgui.flags.Window { "NoCollapse", "NoScrollbar", "NoClosed" }) do
        if imgui.table.Begin("SkeletonColumns", 3, imgui.flags.Table {'Resizable', 'ScrollY'}) then
            imgui.table.SetupColumn("Bones", imgui.flags.TableColumn {'WidthStretch'}, 1.0)
            imgui.table.SetupColumn("AnimationLayer", imgui.flags.TableColumn {'WidthStretch'}, 6.0)
            imgui.table.SetupColumn("Clip", imgui.flags.TableColumn {'WidthStretch'}, 1.0)
            imgui.table.HeadersRow()

            imgui.table.NextColumn()
            local child_width, child_height = imgui.windows.GetContentRegionAvail()
            imgui.windows.BeginChild("##show_skeleton", child_width, child_height, false)
            if joints then
                joint_utils:show_joints(joints.root) 
            end
            imgui.windows.EndChild()

            imgui.table.NextColumn()
            child_width, child_height = imgui.windows.GetContentRegionAvail()
            imgui.windows.BeginChild("##show_layers", child_width, child_height, false)
            -- anim_state.is_playing = iani.is_playing(current_e)
            -- if anim_state.is_playing then
            --     anim_state.current_frame = math.floor(iani.get_time(current_e) * sample_ratio)
            -- end

            imgui.widget.SimpleSequencer(bone_anim, imgui_message)
            anim_state.clip_range_dirty = 0
            local move_type
            local new_frame_idx
            local move_delta
            for k, v in pairs(imgui_message) do
                if k == "pause" then
                    --anim_group_pause(current_e, true)
                    anim_state.current_frame = v
                    --anim_group_set_time(current_e, v / sample_ratio)
                elseif k == "selected_frame" then
                    anim_state.selected_frame = v
                elseif k == "selected_clip_index" then
                    anim_state.selected_clip_index = v
                elseif k == "move_type" then
                    move_type = v
                elseif k == "move_delta" then
                    move_delta = v
                end
            end

            if move_type and move_type ~= 0 then
                on_move_clip(move_type, anim_state.selected_clip_index, move_delta)
            end

            imgui.windows.EndChild()

            imgui.table.NextColumn()
            child_width, child_height = imgui.windows.GetContentRegionAvail()
            imgui.windows.BeginChild("##show_clip", child_width, child_height, false)
            --show_events()
            imgui.windows.EndChild()

            imgui.table.End()
        end
    end
end

function m.bind(e)
    if not e then
        return
    end
    w:sync("animation?in", e)
    if not e.animation then
        return
    end
    joints = joint_utils:get_joints(e)
end

return m